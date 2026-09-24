"""Run root SSH preparation against a temporary directory, never /root."""
import hashlib
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

import yaml


COMPONENTS = Path(__file__).resolve().parents[1]


class RootSSHTests(unittest.TestCase):
    def test_key_preservation_public_key_repair_and_effective_ssh_config(self):
        with tempfile.TemporaryDirectory(prefix='hpc-root-ssh-') as directory:
            root = Path(directory)
            ssh_dir = root / 'ssh'
            # Relocate all paths, omitting root ownership only in this local test.
            source = (COMPONENTS / 'warewulf/tasks/root_ssh.yml').read_text()
            tasks = yaml.safe_load(source.replace('/root/.ssh', str(ssh_dir)))
            for task in tasks:
                for module in ('ansible.builtin.file', 'ansible.builtin.copy', 'ansible.builtin.blockinfile'):
                    if module in task:
                        task[module].pop('owner', None)
                        task[module].pop('group', None)
            play = root / 'test.yml'
            play.write_text(yaml.safe_dump([{
                'hosts': 'localhost', 'connection': 'local', 'gather_facts': False,
                'vars': {'core_cluster': {'cpu_nodes': [{'address': '10.0.2.1'}]}},
                'tasks': tasks}]))

            def run():
                return subprocess.run(['ansible-playbook', '-i', 'localhost,', str(play)],
                                      capture_output=True, text=True,
                                      env=dict(os.environ, ANSIBLE_LOCAL_TEMP=str(root / 'local'),
                                               ANSIBLE_REMOTE_TEMP=str(root / 'remote'),
                                               ANSIBLE_HOME=str(root / 'ansible-home')))

            first = run()
            self.assertEqual(first.returncode, 0, first.stdout + first.stderr)
            private = ssh_dir / 'id_ed25519'
            digest = hashlib.sha256(private.read_bytes()).digest()
            public = (ssh_dir / 'id_ed25519.pub').read_text()
            self.assertTrue(public.startswith('ssh-ed25519 '))
            second = run()
            self.assertEqual(second.returncode, 0, second.stdout + second.stderr)
            self.assertRegex(second.stdout, r'changed=0\s')
            self.assertEqual(hashlib.sha256(private.read_bytes()).digest(), digest)
            (ssh_dir / 'id_ed25519.pub').write_text('stale public key\n')
            repaired = run()
            self.assertEqual(repaired.returncode, 0, repaired.stdout + repaired.stderr)
            self.assertEqual((ssh_dir / 'id_ed25519.pub').read_text(), public)
            self.assertEqual(hashlib.sha256(private.read_bytes()).digest(), digest)
            config = subprocess.run(['ssh', '-F', str(ssh_dir / 'config'), '-G', '10.0.2.1'],
                                    capture_output=True, text=True)
            self.assertEqual(config.returncode, 0, config.stderr)
            self.assertIn('user root\n', config.stdout)
            self.assertIn('identityfile ' + str(private), config.stdout)
            self.assertIn('stricthostkeychecking true', config.stdout)
            self.assertIn('userknownhostsfile ' + str(ssh_dir / 'known_hosts'), config.stdout)
            # An unusable existing identity must fail, never regenerate it.
            private.write_text('invalid existing identity\n')
            invalid = run()
            self.assertNotEqual(invalid.returncode, 0)
            self.assertEqual(private.read_text(), 'invalid existing identity\n')

    def test_node_tasks_have_an_action_and_import_cleanly(self):
        tasks = yaml.safe_load((COMPONENTS / 'warewulf/tasks/node.yml').read_text())
        for task in tasks:
            self.assertTrue(any(key.startswith('ansible.builtin.') for key in task), task)


if __name__ == '__main__':
    unittest.main()
