"""Local component tests. No installers, chroots, services or accounts are changed."""
import base64
import copy
import grp
import importlib.util
import json
import os
from pathlib import Path
import pwd
import shlex
import subprocess
import tempfile
import unittest
import xml.etree.ElementTree as ET

from jinja2 import Environment, FileSystemLoader, StrictUndefined
import yaml

COMPONENTS = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "fingerprint", COMPONENTS / "warewulf/files/image_fingerprint.py")
FINGERPRINT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(FINGERPRINT)
IMAGE_FUNCTIONS = (COMPONENTS / "warewulf/files/image-functions.sh").read_text()


def fixture():
    return {
        "core_components": ["warewulf", "slurm", "spack"],
        "core_cluster": {
            "head": {"name": "head", "address": "10.0.0.1"},
            "network": {"interface": "cluster0", "address": "10.0.0.1", "prefix": 22,
                        "network": "10.0.0.0", "cidr": "10.0.0.0/22",
                        "netmask": "255.255.252.0", "dhcp_start": "10.0.1.1",
                        "dhcp_end": "10.0.1.255"},
            "cpu_image": "rockylinux-9.5",
            "service_users": [
                {"name": "slurm", "group": "slurm", "uid": 960, "gid": 968},
                {"name": "munge", "group": "munge", "uid": 959, "gid": 967}],
            "cpu_nodes": [{"name": "cpu1", "address": "10.0.2.1", "mac": "02:00:00:00:00:01",
                           "slurm": {"sockets": 1, "cores_per_socket": 4,
                                     "threads_per_core": 1, "real_memory_mb": 7000}}],
            "gpu_nodes": [{"name": "gpu1", "address": "10.0.2.4"}],
        },
        "warewulf_authorized_keys": ["ssh-ed25519 AAAATEST public-test-key"],
        "warewulf_head_root_public_key": {"stdout": "ssh-ed25519 AAAAROOT head-root"},
        "warewulf_cluster_zone": "hpc-cluster",
        "slurm_controller_hostname": "actual-hostname",
        "slurm_cluster_name": "mini-hpc", "slurm_controller_port": 6817,
        "slurm_worker_port": 6818, "slurm_srun_ports": "60001-63000",
        "slurm_rpm_release": "23.11.10-1.el9",
        "slurm_job_identity": {"name": "testuser", "uid": 1000, "gid": 1000, "group": "testuser"},
        "slurm_key_data": {"content": base64.b64encode(b"test-only-key").decode()},
        "spack_install_dir": "/opt/spack", "spack_environment_dir": "/opt/spack/environments/hpc",
        "spack_view_dir": "/opt/spack/views/hpc", "spack_build_jobs": 4,
        "spack_packages": ["hdf5"], "spack_gcc": {"stdout": "11.5.0"},
        "lmod_rpm_release": "8.7.65-2.el9",
        "hpc_spack_module_test": {
            "module_path": "/opt/spack/modules/lmod/Core", "name": "hdf5/1.14-testhash",
            "prefix": "/opt/spack/opt/spack/test-hdf5", "command": ["h5dump", "-V"]},
    }


def render(component, name, values=None):
    env = Environment(loader=FileSystemLoader(COMPONENTS / component / "templates"),
                      undefined=StrictUndefined, keep_trailing_newline=True)
    env.filters.update(
        quote=lambda value: shlex.quote(str(value)),
        to_json=json.dumps,
        to_nice_yaml=lambda value, **kw: yaml.safe_dump(value, sort_keys=False, **kw))
    return env.get_template(name).render(values or fixture())


class TemplateTests(unittest.TestCase):
    def test_image_authorizes_head_root_and_controller_without_private_keys(self):
        values = fixture()
        script = render('warewulf', 'image-base.sh.j2', values)
        keys = script.split("<<'HPC_KEYS'\n", 1)[1].split('\nHPC_KEYS', 1)[0]
        self.assertEqual(keys.splitlines(), [values['warewulf_authorized_keys'][0],
                                            values['warewulf_head_root_public_key']['stdout']])
        values['warewulf_authorized_keys'].append(values['warewulf_head_root_public_key']['stdout'])
        script = render('warewulf', 'image-base.sh.j2', values)
        self.assertEqual(script.count(values['warewulf_head_root_public_key']['stdout']), 1)
        self.assertNotIn('PRIVATE KEY', script)

    def test_rendered_image_scripts_parse_and_refuse_execution_on_head(self):
        root = os.stat("/")
        for component, template in [("warewulf", "image-base.sh.j2"),
                                    ("slurm", "cpu-image.sh.j2"), ("spack", "cpu-image.sh.j2"),
                                    ("lmod", "cpu-image.sh.j2")]:
            with self.subTest(component=component):
                script = IMAGE_FUNCTIONS + "\n" + render(component, template)
                syntax = subprocess.run(["bash", "-n"], input=script, text=True, capture_output=True)
                self.assertEqual(syntax.returncode, 0, syntax.stderr)
                result = subprocess.run(["bash"], input=script, text=True, capture_output=True,
                                        env=dict(os.environ, HPC_HEAD_ROOT=f"{root.st_dev}:{root.st_ino}"))
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("Refusing to modify the head root", result.stderr)
                self.assertNotIn("HPC_CHANGED=", result.stdout)

    def test_warewulf_configuration_enables_pxe_pool_and_socket_tftp(self):
        config = yaml.safe_load(render("warewulf", "warewulf.conf.j2"))
        self.assertTrue(config["warewulf"]["host overlay"])
        self.assertFalse(config["warewulf"]["autobuild overlays"])
        self.assertEqual(config["dhcp"]["template"], "default")
        self.assertEqual(config["dhcp"]["range start"], "10.0.1.1")
        self.assertEqual(config["dhcp"]["range end"], "10.0.1.255")
        self.assertEqual(config["tftp"]["systemd name"], "tftp.socket")
        self.assertEqual(config["ssh"]["key types"], [])
        self.assertFalse(config["nfs"]["enabled"])  # dedicated exports.d ownership
        self.assertTrue(config["image mounts"][0]["readonly"])

    def test_firewall_is_bound_to_cluster_interface(self):
        zone = ET.fromstring(render("warewulf", "cluster-zone.xml.j2"))
        self.assertEqual(zone.find("interface").get("name"), "cluster0")
        self.assertNotEqual(zone.get("target"), "ACCEPT")

    def test_slurm_uses_actual_controller_hostname_and_cpu_only(self):
        config = render("slurm", "slurm.conf.j2")
        self.assertIn("SlurmctldHost=actual-hostname(10.0.0.1)", config)
        self.assertIn("NodeName=cpu1 NodeAddr=10.0.2.1 CPUs=4", config)
        self.assertNotIn("gpu1", config)
        self.assertNotIn("Prolog=", config)
        self.assertEqual(config.count("TaskPlugin="), 1)

    def test_worker_time_source_and_authentication_startup(self):
        script = render('slurm', 'cpu-image.sh.j2')
        self.assertIn('server 10.0.0.1 iburst', script)
        self.assertIn('makestep 1.0 3', script)
        self.assertIn('enable_service chronyd', script)
        self.assertIn('enable_service munge', script)
        self.assertIn('enable_service slurmd', script)
        self.assertIn('After=chronyd.service', script)
        self.assertIn('Requires=munge.service', script)
        self.assertIn('After=munge.service', script)
        self.assertNotIn('systemctl start', script)
        self.assertNotIn('local stratum', script)

    def test_spack_environment_and_optional_modules(self):
        values = fixture()
        config = yaml.safe_load(render("spack", "spack.yaml.j2", values))["spack"]
        self.assertEqual(config["specs"], ["hdf5"])
        self.assertEqual(config["packages"]["all"]["target"], ["x86_64"])
        self.assertEqual(config["view"], "/opt/spack/views/hpc")
        self.assertEqual(yaml.safe_load(render("spack", "modules.yaml.j2", values))
                         ["modules"]["default"]["enable"], [])
        values["core_components"].append("lmod")
        self.assertEqual(yaml.safe_load(render("spack", "modules.yaml.j2", values))
                         ["modules"]["default"]["enable"], ["lmod"])
        self.assertEqual(yaml.safe_load(render("spack", "modules.yaml.j2", values))
                         ["modules"]["default"]["lmod"]["hierarchy:"], [])


class ImageHelperTests(unittest.TestCase):
    def run_helper(self, commands):
        return subprocess.run(["bash"], input=IMAGE_FUNCTIONS + "\n" + commands,
                              env=dict(os.environ, HPC_HEAD_ROOT="test-image-context"),
                              text=True, capture_output=True)

    def test_file_updates_are_repeatable_and_repair_mode(self):
        user = pwd.getpwuid(os.getuid()).pw_name
        group = grp.getgrgid(os.getgid()).gr_name
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "managed"
            command = (f"put_file {shlex.quote(str(path))} 0600 {shlex.quote(user)} "
                       f"{shlex.quote(group)} <<'DATA'\nhello\nDATA\necho HPC_CHANGED=$hpc_changed\n")
            first = self.run_helper(command)
            self.assertEqual(first.returncode, 0, first.stderr)
            self.assertIn("HPC_CHANGED=1", first.stdout)
            self.assertIn("HPC_CHANGED=0", self.run_helper(command).stdout)
            path.chmod(0o644)
            self.assertIn("HPC_CHANGED=1", self.run_helper(command).stdout)
            self.assertEqual(path.read_text(), "hello\n")

    def test_existing_identity_mismatch_stops_before_account_mutation(self):
        # Shell-function stubs read an invented account database; no useradd runs.
        commands = """
getent() {
    case "$1:$2" in
        passwd:slurm) echo 'slurm:x:961:968::/:/sbin/nologin';;
        passwd:960) return 2;;
        group:slurm|group:968) echo 'slurm:x:968:';;
        *) return 2;;
    esac
}
id() { if [[ "$1" == -u ]]; then echo 961; else echo 968; fi; }
useradd() { echo SHOULD_NOT_MUTATE; exit 99; }
groupadd() { echo SHOULD_NOT_MUTATE; exit 99; }
ensure_identity slurm 960 slurm 968 /var/lib/slurm /sbin/nologin
"""
        result = self.run_helper(commands)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("refusing renumbering", result.stderr)
        self.assertNotIn("SHOULD_NOT_MUTATE", result.stdout)


class PublicationTests(unittest.TestCase):
    def test_content_ownership_metadata_and_symlink_changes_affect_fingerprint(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / "etc").mkdir()
            config = root / "etc/config"
            config.write_text("original")
            before = FINGERPRINT.fingerprint(root)
            config.write_text("updated")
            content = FINGERPRINT.fingerprint(root)
            self.assertNotEqual(before, content)
            config.chmod(0o600)
            mode = FINGERPRINT.fingerprint(root)
            self.assertNotEqual(content, mode)
            (root / "link").symlink_to("etc/config")
            self.assertNotEqual(mode, FINGERPRINT.fingerprint(root))

    def test_runtime_cache_and_publication_marker_do_not_force_rebuild(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            for name in ["etc", "run", "var/cache", "var/log"]:
                (root / name).mkdir(parents=True, exist_ok=True)
            before = FINGERPRINT.fingerprint(root)
            for name in ["etc/hpc-image-id", "run/pid", "var/cache/test", "var/log/test"]:
                (root / name).write_text("volatile")
            self.assertEqual(before, FINGERPRINT.fingerprint(root))


class EntryPointTests(unittest.TestCase):
    def test_all_requested_entry_points_exist(self):
        for role, phases in {"warewulf": ["head", "image_prepare", "publish", "verify"],
                             "slurm": ["head", "cpu_image", "verify"],
                             "spack": ["head", "cpu_image", "verify"],
                             "lmod": ["head", "cpu_image", "verify"]}.items():
            for phase in phases:
                with self.subTest(role=role, phase=phase):
                    tasks = yaml.safe_load((COMPONENTS / role / "tasks" / f"{phase}.yml").read_text())
                    self.assertTrue(tasks)

    def test_image_exec_never_auto_builds_or_syncs_identities(self):
        count = 0
        for role in ["warewulf", "slurm", "spack", "lmod"]:
            for path in (COMPONENTS / role / "tasks").glob("*.yml"):
                text = path.read_text()
                for line in text.splitlines():
                    if "argv: [wwctl, image, exec," in line:
                        count += 1
                        self.assertIn("--build=false", line)
                        self.assertIn("--syncuser=false", line)
                        self.assertIn("HPC_HEAD_ROOT=", line)
        self.assertEqual(count, 6)


if __name__ == "__main__":
    unittest.main()
