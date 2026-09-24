"""Exercise real acceptance tasks with fake tools, never live services."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

import yaml


SLURM = Path(__file__).resolve().parents[1] / 'slurm'


class SlurmAcceptanceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='hpc-slurm-tests-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()

    def tool(self, name, body):
        path = self.bin / name
        path.write_text('#!/bin/bash\nset -eu\n' + body + '\n')
        path.chmod(0o755)

    def run_tasks(self, tasks, variables=None):
        config = self.root / 'ansible.cfg'
        config.write_text('[defaults]\nretry_files_enabled = False\n')
        playbook = self.root / 'test.yml'
        playbook.write_text(yaml.safe_dump([{
            'hosts': 'localhost', 'connection': 'local', 'gather_facts': False,
            'become': False, 'vars': variables or {},
            'environment': {'PATH': str(self.bin) + ':' + os.environ['PATH']},
            'tasks': tasks + [{'ansible.builtin.debug': {'msg': 'CHECKS_PASSED'}}],
        }]))
        return subprocess.run(
            ['ansible-playbook', '-i', 'localhost,', str(playbook)],
            env=dict(os.environ, ANSIBLE_CONFIG=str(config),
                     ANSIBLE_LOCAL_TEMP=str(self.root / 'local'),
                     ANSIBLE_REMOTE_TEMP=str(self.root / 'remote'),
                     ANSIBLE_HOME=str(self.root / 'home'), ANSIBLE_NOCOLOR='1'),
            capture_output=True, text=True, timeout=45)

    def test_unsynchronized_clock_stops_following_tasks(self):
        tasks = yaml.safe_load((SLURM / 'tasks/time_check.yml').read_text())
        self.assertGreater(tasks[0]['retries'], 0)
        self.assertLessEqual(tasks[0]['retries'] * tasks[0]['delay'], 120)
        # Keep failure tests fast; preserve the actual command/until condition.
        tasks[0].update(retries=0, delay=0)
        for rc in [1, 0]:
            with self.subTest(rc=rc):
                self.tool('chronyc', '[[ "$*" == "waitsync 1 1.0 0.0 1" ]]\nexit ' + str(rc))
                result = self.run_tasks(tasks)
                self.assertEqual(result.returncode == 0, rc == 0, result.stdout + result.stderr)
                self.assertEqual('CHECKS_PASSED' in result.stdout, rc == 0)

    def test_selected_ntp_server_must_be_the_head(self):
        tasks = yaml.safe_load((SLURM / 'tasks/verify_node.yml').read_text())
        assertion = next(t for t in tasks if t['name'] == "Require the head to be the worker's selected NTP server")
        for source, success in [
            ('^* 10.0.0.1 3 6 377 12 +12us[+13us] +/- 1ms', True),
            ('^* 10.0.0.2 3 6 377 12 +12us[+13us] +/- 1ms', False),
            ('^? 10.0.0.1 0 6 0 - +0ns[+0ns] +/- 0ns', False),
        ]:
            with self.subTest(source=source):
                result = self.run_tasks([assertion], {
                    'core_cluster': {'head': {'address': '10.0.0.1'}},
                    'slurm_worker_time_sources': {'stdout_lines': [source]},
                })
                self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)

    def test_munge_decode_failure_stops_following_tasks_and_hides_credentials(self):
        tasks = yaml.safe_load((SLURM / 'tasks/auth_check.yml').read_text())
        self.tool('munge', "echo TEST_ONLY_CREDENTIAL")
        for rc in [1, 0]:
            with self.subTest(rc=rc):
                self.tool('unmunge', 'read -r credential\n[[ "$credential" == TEST_ONLY_CREDENTIAL ]]\nexit ' + str(rc))
                result = self.run_tasks(tasks)
                self.assertEqual(result.returncode == 0, rc == 0, result.stdout + result.stderr)
                self.assertEqual('CHECKS_PASSED' in result.stdout, rc == 0)
                self.assertNotIn('TEST_ONLY_CREDENTIAL', result.stdout)


if __name__ == '__main__':
    unittest.main()
