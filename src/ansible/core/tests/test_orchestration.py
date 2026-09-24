"""Run Ansible against temporary recording roles, never real installers.

Successful orchestration tests replace only the copied preflight task file with
a recording task. Real preflight rejection is tested separately. These tests
establish sequencing and failure behavior, not live-cluster functionality.
"""
import base64
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

import yaml


CORE = Path(__file__).resolve().parents[1]
ANSIBLE = CORE.parent


class OrchestrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hpc-core-tests-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.role = self.root / "roles/hpc_core"
        shutil.copytree(CORE / "roles/hpc_core", self.role)
        self.components = self.root / "components"
        self.write(self.components / 'warewulf/tasks/security.yml', [])
        self.write(self.components / 'warewulf/tasks/verify_publication.yml', [])
        self.catalog = yaml.safe_load((self.role / "vars/main.yml").read_text())
        for phase in self.catalog["core_deploy_phases"] + self.catalog["core_verify_phases"]:
            component, entry = phase["component"], phase["entry"]
            self.write(self.components / component / "tasks" / f"{entry}.yml", [
                {"name": "Record component execution", "ansible.builtin.set_fact": {
                    "core_test_trace": "{{ core_test_trace | default([]) + ['" + component + "/" + entry + "'] }}"}},
                {"name": "Report recorded phase", "ansible.builtin.debug": {
                    "msg": f"PHASE_RAN::{component}/{entry}"}},
            ])
        # A handler test ensures the next phase sees completed prior work.
        self.write(self.components / "warewulf/handlers/main.yml", [
            {"name": "Record Warewulf handler", "ansible.builtin.set_fact": {
                "core_test_trace": "{{ core_test_trace + ['warewulf/handler'] }}"}},
        ])
        head = self.components / "warewulf/tasks/head.yml"
        tasks = yaml.safe_load(head.read_text())
        tasks[0].update({"changed_when": True, "notify": "Record Warewulf handler"})
        self.write(head, tasks)
        self.inventory = self.root / "hosts.yml"
        self.write(self.inventory, {"all": {"children": {
            "headnode": {"hosts": {"head": {"ansible_connection": "local"}}},
            "cpu_nodes": {"hosts": {"cpu1": {
                "ansible_host": "10.0.2.1", "cluster_architecture": "x86_64",
                "cluster_mac": "02:00:00:00:00:01", "slurm_sockets": 1,
                "slurm_cores_per_socket": 4, "slurm_threads_per_core": 1,
                "slurm_real_memory_mb": 7000}}},
            "gpu_nodes": {"hosts": {"gpu1": {"ansible_host": "10.0.2.4"}}},
        }}})
        # Exercise the real Ansible filter and templating with a synthetic snapshot.
        self.preflight = yaml.safe_load((CORE / "roles/hpc_core/tasks/preflight.yml").read_text())
        model_task = next(task for task in self.preflight
                          if task["name"] == "Construct the validated cluster contract")
        setup = {
            "schema_version": 1, "required_distribution": "Rocky",
            "required_rocky_major_version": "9", "network_interface": "cluster0",
            "network_address": "10.0.0.1", "network_prefix": 22,
            "service_users": [
                {"name": "slurm", "group": "slurm", "uid": 960, "gid": 968},
                {"name": "munge", "group": "munge", "uid": 959, "gid": 967},
            ],
        }
        self.write(self.role / "tasks/preflight.yml", [
            {"name": "Simulated setup handoff", "ansible.builtin.set_fact": {
                "core_setup_contents": {"content": base64.b64encode(yaml.safe_dump(setup).encode()).decode()}}},
            model_task,
            {"name": "Confirm component contract delivery", "ansible.builtin.assert": {
                "that": ["core_cluster.cpu_nodes[0].name == 'cpu1'",
                         "core_cluster.cpu_nodes[0].slurm.real_memory_mb == 7000"]}},
            {"name": "Report simulated handoff", "ansible.builtin.debug": {"msg": "TEST_HANDOFF_EXECUTED"}},
        ])
        self.playbook = self.root / "site.yml"
        expected = [p["component"] + "/" + p["entry"] for p in self.catalog["core_deploy_phases"]]
        expected.insert(1, "warewulf/handler")
        self.write(self.playbook, [{
            "name": "Test orchestration", "hosts": "headnode", "gather_facts": False,
            "become": False, "any_errors_fatal": True,
            "vars": {"core_components_dir": str(self.components), "core_checkpoint_enabled": False,
                     "core_lock_dir": str(self.root / 'deploy-lock'), "core_checkpoint_probes": {}},
            "roles": ["hpc_core"],
            "post_tasks": [{"name": "Verify exact phase and handler order", "ansible.builtin.assert": {
                "that": ["core_test_trace == " + repr(expected)]}, "when": "core_action == 'deploy'"}],
        }])
        self.config = self.root / "ansible.cfg"
        self.config.write_text("[defaults]\nroles_path = " + str(self.root / "roles") + "\n")
        self.env = dict(os.environ, ANSIBLE_CONFIG=str(self.config),
                        ANSIBLE_LOCAL_TEMP=str(self.root / "local"),
                        ANSIBLE_REMOTE_TEMP=str(self.root / "remote"),
                        ANSIBLE_HOME=str(self.root / "ansible-home"),
                        ANSIBLE_NOCOLOR="1", ANSIBLE_BECOME_ASK_PASS="False")

    def write(self, path, data):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(yaml.safe_dump(data, sort_keys=False))

    def run_play(self, *args, playbook=None, config=None):
        env = dict(self.env)
        if config:
            env["ANSIBLE_CONFIG"] = str(config)
        result = subprocess.run(
            ["ansible-playbook", "-i", str(self.inventory), str(playbook or self.playbook), *args],
            env=env, cwd=self.root, text=True, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, timeout=60)
        return result

    def test_deploy_orders_phases_and_flushes_handlers_without_contacting_compute(self):
        result = self.run_play()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("PHASE_RAN::warewulf/publish", result.stdout)
        self.assertNotIn("PHASE_RAN::warewulf/verify", result.stdout)
        self.assertNotIn("unreachable=1", result.stdout)

    def test_contract_accepts_actual_setup_serialization(self):
        # Render setup's real snapshot template without executing its role.
        setup = ANSIBLE / 'setup'
        config_tasks = yaml.safe_load((setup / 'roles/config/tasks/main.yml').read_text())
        snapshot = next(t['ansible.builtin.copy']['content'] for t in config_tasks
                        if t['name'] == 'Write the effective setup configuration')
        template = self.root / 'setup-snapshot.j2'
        template.write_text(snapshot)
        play = yaml.safe_load(self.playbook.read_text())
        play[0]['vars_files'] = [str(setup / name) for name in [
            'vars/main.yml', 'vars/system.yml', 'vars/packages.yml',
            'vars/security.yml', 'roles/bootstrap/defaults/main.yml']]
        self.write(self.playbook, play)
        preflight = self.role / 'tasks/preflight.yml'
        tasks = yaml.safe_load(preflight.read_text())
        tasks[0]['ansible.builtin.set_fact']['core_setup_contents'] = {
            'content': "{{ lookup('ansible.builtin.template', '" + str(template) + "') | b64encode }}"}
        self.write(preflight, tasks)
        result = self.run_play()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('TEST_HANDOFF_EXECUTED', result.stdout)
        self.assertIn('PHASE_RAN::warewulf/publish', result.stdout)

    def test_component_failure_prevents_publication_and_success(self):
        self.write(self.components / "slurm/tasks/head.yml", [
            {"name": "Simulate installation failure", "ansible.builtin.fail": {"msg": "TEST_INSTALL_FAILED"}},
        ])
        result = self.run_play()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("TEST_INSTALL_FAILED", result.stdout)
        self.assertFalse((self.root / 'deploy-lock').exists(), result.stdout)
        self.assertNotIn("PHASE_RAN::warewulf/publish", result.stdout)
        self.assertNotIn("Selected components and CPU image publication finished.", result.stdout)

    def test_preparation_runs_only_two_phases_and_flushes_handlers(self):
        # Neither publication nor unrelated component files are needed here.
        (self.components / "warewulf/tasks/publish.yml").unlink()
        (self.components / "warewulf/tasks/verify.yml").unlink()
        shutil.rmtree(self.components / "lmod")
        play = yaml.safe_load(self.playbook.read_text())
        play[0]["post_tasks"][0]["ansible.builtin.assert"]["that"] = [
            "core_test_trace == ['warewulf/head', 'warewulf/handler', 'warewulf/image_prepare']"]
        self.write(self.playbook, play)
        # The synthetic handoff's resource assertion assumes Slurm is selected.
        tasks = yaml.safe_load((self.role / "tasks/preflight.yml").read_text())
        tasks = [t for t in tasks if t['name'] != 'Confirm component contract delivery']
        self.write(self.role / "tasks/preflight.yml", tasks)
        result = self.run_play('-e', json.dumps({
            'core_stage': 'warewulf_prepare', 'core_components': ['warewulf']}))
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('TEST_HANDOFF_EXECUTED', result.stdout)
        self.assertIn('Warewulf head and image preparation finished.', result.stdout)
        self.assertNotIn('Selected components and CPU image publication finished.', result.stdout)

    def test_preparation_plan_uses_actual_entries_without_lmod(self):
        result = self.run_play('-e', json.dumps({
            'core_action': 'plan', 'core_stage': 'warewulf_prepare',
            'core_components': ['warewulf'], 'core_components_dir': str(ANSIBLE / 'components')}))
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('"missing_component_entry_points": []', result.stdout)
        self.assertNotIn('"entry": "publish"', result.stdout)
        self.assertNotIn('PHASE_RAN::', result.stdout)

    def test_invalid_preparation_options_fail_before_handoff(self):
        for options in [
            {'core_stage': 'typo'},
            {'core_stage': 'warewulf_prepare'},
            {'core_stage': 'warewulf_prepare', 'core_components': ['warewulf'], 'core_action': 'verify'},
        ]:
            with self.subTest(options=options):
                result = self.run_play('-e', json.dumps(options))
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertNotIn('TEST_HANDOFF_EXECUTED', result.stdout)
                self.assertNotIn('PHASE_RAN::', result.stdout)

    def test_missing_entry_fails_before_handoff_or_any_installation(self):
        (self.components / "slurm/tasks/cpu_image.yml").unlink()
        result = self.run_play()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("Component integration is incomplete", result.stdout)
        self.assertNotIn("TEST_HANDOFF_EXECUTED", result.stdout)
        self.assertNotIn("PHASE_RAN::", result.stdout)

    def test_plan_runs_against_all_actual_components(self):
        result = self.run_play("-e", "core_action=plan", "-e", json.dumps({
            "core_components_dir": str(ANSIBLE / "components")}),
            playbook=CORE / "playbooks/site.yml", config=ANSIBLE / "ansible.cfg")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('"missing_component_entry_points": []', result.stdout)
        self.assertIn("changed=0", result.stdout)

    def test_actual_deploy_refuses_missing_components_without_host_access(self):
        result = self.run_play('-e', json.dumps({'core_components_dir': str(self.root / 'missing-components')}),
                               playbook=CORE / "playbooks/site.yml", config=ANSIBLE / "ansible.cfg")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("Component integration is incomplete", result.stdout)
        self.assertNotIn("Inspect the setup handoff files on the head", result.stdout)

    def test_actual_preflight_rejects_missing_setup_before_component_execution(self):
        result = self.run_play("-e", json.dumps({
            "core_action": "preflight", "ansible_become": False,
            "core_setup_file": str(self.root / "missing-setup.yml"),
            "core_setup_complete_flag": str(self.root / "missing-flag")}),
            playbook=CORE / "playbooks/site.yml", config=ANSIBLE / "ansible.cfg")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("Complete setup first", result.stdout)
        self.assertNotIn("Gather the head operating system facts", result.stdout)

    def test_invalid_dependency_and_check_mode_fail_before_installation(self):
        for args in [("--check",), ("-e", '{"core_components":["warewulf","lmod"]}')]:
            with self.subTest(args=args):
                result = self.run_play(*args)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertNotIn("PHASE_RAN::", result.stdout)

    def test_preflight_never_invokes_available_installers(self):
        result = self.run_play("-e", "core_action=preflight")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("TEST_HANDOFF_EXECUTED", result.stdout)
        self.assertNotIn("PHASE_RAN::", result.stdout)

    def test_verification_only_runs_acceptance_entries(self):
        inventory = yaml.safe_load(self.inventory.read_text())
        inventory["all"]["children"]["cpu_nodes"]["hosts"]["cpu1"]["ansible_connection"] = "local"
        self.write(self.inventory, inventory)
        result = self.run_play("-e", "core_action=verify")
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("PHASE_RAN::slurm/verify", result.stdout)
        self.assertNotIn("PHASE_RAN::slurm/head", result.stdout)
        self.assertIn("All selected component acceptance checks passed", result.stdout)

    def test_actual_entry_point_rejects_partial_tag_runs(self):
        result = self.run_play("--tags", "slurm", playbook=CORE / "playbooks/site.yml",
                               config=ANSIBLE / "ansible.cfg")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("partial runs through tags are unsupported", result.stdout)

    def test_live_identity_assertion_fails_on_uid_drift(self):
        task = next(task for task in self.preflight if task["name"] == "Require unchanged Slurm and Munge identities")
        play = self.root / "identity.yml"
        base = {"name": "Test actual identity assertion", "hosts": "headnode", "gather_facts": False,
                "vars": {"core_cluster": {"service_users": [
                    {"name": "slurm", "group": "slurm", "uid": 960, "gid": 968}]},
                    "ansible_facts": {"getent_passwd": {"slurm": ["x", "960", "968", "", "/", "/sbin/nologin"]},
                                      "getent_group": {"slurm": ["x", "968", ""]}}}, "tasks": [task]}
        self.write(play, [base])
        result = self.run_play(playbook=play)
        self.assertEqual(result.returncode, 0, result.stdout)
        base["vars"]["ansible_facts"]["getent_passwd"]["slurm"][1] = "961"
        self.write(play, [base])
        result = self.run_play(playbook=play)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("Core never changes head UID/GID assignments", result.stdout)

    def test_live_network_assertion_rejects_cluster_default_route(self):
        task = next(task for task in self.preflight
                    if task["name"] == "Verify setup address and management-interface separation")
        play = self.root / "network.yml"
        base = {"name": "Test actual network assertion", "hosts": "headnode", "gather_facts": False,
                "vars": {"core_cluster": {"network": {"interface": "cluster0", "address": "10.0.0.1", "prefix": 22}},
                         "core_interface_state": {"stdout": json.dumps([
                             {"addr_info": [{"local": "10.0.0.1", "prefixlen": 22}]}])},
                         "core_default_routes": {"stdout": json.dumps([{"dev": "public0"}])}}, "tasks": [task]}
        self.write(play, [base])
        result = self.run_play(playbook=play)
        self.assertEqual(result.returncode, 0, result.stdout)
        base["vars"]["core_default_routes"]["stdout"] = json.dumps([{"dev": "public0"}, {"dev": "cluster0"}])
        self.write(play, [base])
        result = self.run_play(playbook=play)
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("Core will not reconfigure the NIC", result.stdout)


if __name__ == "__main__":
    unittest.main()
