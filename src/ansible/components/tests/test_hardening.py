"""Release-input validation and an optional isolated real-wwctl probe."""
import os
import importlib.util
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

import yaml
from jinja2 import Environment, FileSystemLoader

COMPONENTS = Path(__file__).resolve().parents[1]


class SpackOwnershipTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('spack_owner', COMPONENTS / 'spack/files/migrate_owner.py')
        self.owner = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.owner)
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.tree = self.root / 'spack'
        self.tree.mkdir()
        self.outside = self.root / 'outside'
        self.outside.write_text('must remain untouched')

    def test_nested_symlinks_do_not_change_external_owners(self):
        (self.tree / 'link').symlink_to(self.outside)
        (self.tree / 'package').write_text('software')
        touched = []
        with patch.object(self.owner.os, 'fchown', side_effect=lambda fd, uid, gid: touched.append(os.fstat(fd).st_ino)):
            self.assertTrue(self.owner.migrate([str(self.tree)], os.getuid()+10000, os.getgid()+10000))
        self.assertNotIn(self.outside.stat().st_ino, touched)
        self.assertIn((self.tree / 'package').stat().st_ino, touched)

    def test_redirected_root_and_legacy_hardlinks_fail_closed(self):
        alias = self.root / 'alias'
        alias.symlink_to(self.tree)
        with self.assertRaises(ValueError):
            self.owner.migrate([str(alias)], os.getuid()+10000, os.getgid()+10000)
        os.link(self.outside, self.tree / 'shared-inode')
        touched = []
        with patch.object(self.owner.os, 'fchown', side_effect=lambda fd, uid, gid: touched.append(os.fstat(fd).st_ino)):
            with self.assertRaises(ValueError):
                self.owner.migrate([str(self.tree)], os.getuid()+10000, os.getgid()+10000)
        self.assertNotIn(self.outside.stat().st_ino, touched)

    def test_internal_hardlinks_migrate_without_touching_outside_files(self):
        package = self.tree / 'package'
        package.write_text('software')
        os.link(package, self.tree / 'package-alias')
        touched = []
        with patch.object(self.owner.os, 'fchown', side_effect=lambda fd, uid, gid: touched.append(os.fstat(fd).st_ino)):
            self.assertTrue(self.owner.migrate([str(self.tree)], os.getuid()+10000, os.getgid()+10000))
        self.assertIn(package.stat().st_ino, touched)
        self.assertNotIn(self.outside.stat().st_ino, touched)


class SecurityInputsTests(unittest.TestCase):
    def test_no_asset_keys_required_but_unpinned_inputs_are_rejected(self):
        tasks = yaml.safe_load((COMPONENTS / 'warewulf/tasks/security.yml').read_text())
        checks = [task for task in tasks if task['name'] ==
                  'Require verified release inputs before changing the head']
        self.assertEqual(len(checks), 1)
        base = dict(warewulf_release_dir='/var/lib/hpc-setup/releases',
                    core_cluster={'cpu_nodes': [{'name': 'cpu1'}, {'name': 'cpu2'}]},
                    warewulf_rpm_checksum='sha256:'+'c'*64,
                    warewulf_image_source='docker://example/image@sha256:'+'d'*64)
        cases = [({}, True),
                 ({'warewulf_rpm_checksum': ''}, False),
                 ({'warewulf_image_source': 'docker://example/image:latest'}, False),
                 ({'warewulf_release_dir': '/var/lib/unsafe path'}, False)]
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / 'check.yml'
            for overrides, success in cases:
                with self.subTest(overrides=overrides):
                    path.write_text(yaml.safe_dump([{
                        'hosts': 'localhost', 'connection': 'local', 'gather_facts': False,
                        'vars': dict(base, **overrides), 'tasks': checks}]))
                    result = subprocess.run(['ansible-playbook', '-i', 'localhost,', str(path)],
                                            capture_output=True, text=True)
                    self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)


@unittest.skipUnless(os.environ.get('HPC_WAREWULF_SOURCE') and shutil.which('wwctl'),
                     'set HPC_WAREWULF_SOURCE to pinned 4.6.4 sources and install wwctl')
class WarewulfStagingTests(unittest.TestCase):
    def test_pxe_pool_then_mac_matched_static_network(self):
        with tempfile.TemporaryDirectory(prefix='hpc-ww-stage-') as temp:
            root = Path(temp)
            shutil.copytree(Path(os.environ['HPC_WAREWULF_SOURCE']) / 'overlays',
                            root / 'dist/warewulf/overlays', symlinks=True)
            (root / 'etc/warewulf').mkdir(parents=True)
            nodes = root / 'etc/warewulf/nodes.conf'
            nodes.write_text('nodes: {}\nnodeprofiles: {}\n')
            (root / 'out').mkdir()
            config = root / 'config.yml'
            template = Environment(loader=FileSystemLoader(COMPONENTS / 'warewulf/templates'))
            settings = yaml.safe_load(template.get_template('warewulf.conf.j2').render(core_cluster={
                'network': {'address': '10.0.0.1', 'netmask': '255.255.252.0',
                            'network': '10.0.0.0', 'dhcp_start': '10.0.1.1', 'dhcp_end': '10.0.1.255'}}))
            settings['paths'].update(datadir=str(root / 'dist'), sysconfdir=str(root / 'etc'),
                                     wwprovisiondir=str(root / 'provision'), wwoverlaydir=str(root / 'site'))
            config.write_text(yaml.safe_dump(settings))
            env = dict(os.environ, WAREWULFCONF=str(config))
            data = {'cpu-test': {'image name': 'test-image',
                                'network devices': {'default': {'hwaddr': '02:00:00:00:00:01',
                                    'ipaddr': '10.0.2.1', 'netmask': '255.255.252.0', 'primary': True,
                                    'device': 'eth0', 'gateway': '10.0.0.1', 'onboot': True}}}}
            for argv, stdin in [(['wwctl', 'node', 'import', '--yes', '/dev/stdin'], yaml.safe_dump(data)),
                                (['wwctl', 'node', 'export', 'cpu-test'], None),
                                (['wwctl', 'overlay', 'build', '--overlay', 'host', '--output',
                                  str(root / 'out'), 'cpu-test'], None),
                                (['wwctl', 'overlay', 'build', '--overlay', 'NetworkManager', '--output',
                                  str(root / 'out'), 'cpu-test'], None)]:
                result = subprocess.run(argv, input=stdin, env=env, text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stderr)
            dhcp = (root / 'out/etc/dhcp/dhcpd.conf').read_text()
            self.assertIn('range 10.0.1.1 10.0.1.255;', dhcp)
            self.assertIn('next-server 10.0.0.1;', dhcp)
            self.assertIn('/ipxe/${mac:hexhyp}', dhcp)
            self.assertNotIn('fixed-address', dhcp)
            self.assertNotIn('10.0.2.1', dhcp)
            network = (root / 'out/etc/NetworkManager/system-connections/warewulf-default.conf').read_text()
            for setting in ['method=manual', 'address=10.0.2.1/22', 'mac-address=02:00:00:00:00:01',
                            'interface-name=eth0', 'gateway=10.0.0.1']:
                self.assertIn(setting, network)
            # Exercise the same lease-policy tasks used by both initial setup and
            # publication, including DHCP syntax checking and repeatability.
            playbook = root / 'policy.yml'
            playbook.write_text(yaml.safe_dump([{
                'hosts': 'localhost', 'connection': 'local', 'gather_facts': False,
                'vars': {'warewulf_dhcp_config_path': str(root / 'out/etc/dhcp/dhcpd.conf')},
                'tasks': [{'ansible.builtin.import_tasks': str(COMPONENTS / 'warewulf/tasks/dhcp_policy.yml')}]}]))
            for run in range(2):
                result = subprocess.run(['ansible-playbook', '-i', 'localhost,', str(playbook)],
                                        text=True, capture_output=True)
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                if run == 1:
                    self.assertIn('changed=0', result.stdout)
            self.assertEqual((root / 'out/etc/dhcp/dhcpd.conf').read_text().count('ignore-client-uids true;'), 1)
            node = yaml.safe_load(nodes.read_text())['nodes']['cpu-test']
            self.assertEqual(node['network devices']['default']['hwaddr'], '02:00:00:00:00:01')
