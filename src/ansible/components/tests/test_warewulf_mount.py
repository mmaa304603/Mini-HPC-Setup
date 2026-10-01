"""Run the real NFS acceptance assertion without mounting or changing services."""
import json
from pathlib import Path
import subprocess
import unittest

import yaml
import test_slurm


TASKS = Path(__file__).resolve().parents[1] / 'warewulf/tasks/verify_node.yml'


class WarewulfMountTests(unittest.TestCase):
    setUp = test_slurm.SlurmAcceptanceTests.setUp
    run_tasks = test_slurm.SlurmAcceptanceTests.run_tasks

    def test_automount_layers_and_invalid_exports(self):
        assertion = yaml.safe_load(TASKS.read_text())[-1]
        nfs = dict(target='/opt/spack', source='10.0.0.1:/opt/spack',
                   fstype='nfs4', options='ro,relatime,vers=4.2')
        autofs = dict(target='/opt/spack', source='systemd-1',
                      fstype='autofs', options='rw,relatime')
        cases = [
            ([autofs, nfs], True),
            ([nfs, autofs], True),
            ([nfs], True),
            ([dict(nfs, fstype='nfs')], True),
            ([autofs], False),
            ([], False),
            ([autofs, dict(nfs, source='10.0.0.2:/opt/spack')], False),
            ([autofs, dict(nfs, options='rw,relatime')], False),
            ([dict(nfs, target='/opt')], False),
            ([nfs, nfs], False),
        ]
        for mounts, success in cases:
            with self.subTest(mounts=mounts):
                result = self.run_tasks([assertion], {
                    'core_components': ['spack'],
                    'core_cluster': {'head': {'address': '10.0.0.1'}},
                    'warewulf_verify_node': {'name': 'cpu01'},
                    'warewulf_spack_export': '/opt/spack',
                    'warewulf_software_mount': {'stdout': json.dumps({'filesystems': mounts})},
                })
                self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
                if not success:
                    self.assertIn('must mount', result.stdout)

    def test_findmnt_command_returns_flat_explicit_columns(self):
        task = next(t for t in yaml.safe_load(TASKS.read_text())
                    if t['name'] == 'Inspect the software filesystem')
        argv = task['ansible.builtin.command']['argv']
        argv = ['/' if arg == '{{ warewulf_spack_export }}' else arg for arg in argv]
        result = subprocess.run(argv, capture_output=True, text=True, check=True)
        mounts = json.loads(result.stdout)['filesystems']
        self.assertTrue(mounts)
        for mount in mounts:
            self.assertEqual(mount['target'], '/')
            self.assertTrue({'source', 'fstype', 'options'} <= set(mount))
            self.assertNotIn('children', mount)


if __name__ == '__main__':
    unittest.main()
