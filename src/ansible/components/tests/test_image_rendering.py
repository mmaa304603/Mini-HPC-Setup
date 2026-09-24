"""Check actual Ansible rendering of nested image-file heredocs."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

import yaml

from test_components import COMPONENTS, fixture


class ImageRenderingTests(unittest.TestCase):
    def test_real_ansible_preserves_file_boundaries(self):
        with tempfile.TemporaryDirectory(prefix='hpc-image-render-') as directory:
            root = Path(directory)
            components = ['warewulf', 'slurm', 'spack', 'lmod']
            tasks = []
            for component in components:
                name = 'image-base.sh.j2' if component == 'warewulf' else 'cpu-image.sh.j2'
                source = str(COMPONENTS / component / 'templates' / name)
                tasks.append({'ansible.builtin.copy': {
                    'content': "{{ lookup('ansible.builtin.template', '" + source + "') }}",
                    'dest': str(root / (component + '.sh'))}})
                entry = 'image_prepare.yml' if component == 'warewulf' else 'cpu_image.yml'
                phase = yaml.safe_load((COMPONENTS / component / 'tasks' / entry).read_text())
                task = next(t for t in phase if 'failed_when' in t)
                tasks.append({
                    'name': 'Reject incomplete image scripts even with exit status zero',
                    'ansible.builtin.assert': {
                        'that': ['(' + task['failed_when'] + ') == item.failed']},
                    'vars': {task['register']: '{{ item.result }}'},
                    'loop': [
                        {'result': {'rc': 0, 'stdout': 'HPC_CHANGED=0\n'}, 'failed': False},
                        {'result': {'rc': 0, 'stdout': 'HPC_CHANGED=1\n'}, 'failed': False},
                        {'result': {'rc': 0, 'stdout': 'Complete!\n'}, 'failed': True},
                        {'result': {'rc': 1, 'stdout': 'HPC_CHANGED=1\n'}, 'failed': True}]})
            play = root / 'render.yml'
            play.write_text(yaml.safe_dump([{
                'hosts': 'localhost', 'connection': 'local', 'gather_facts': False,
                'vars': fixture(), 'tasks': tasks}]))
            result = subprocess.run(['ansible-playbook', '-i', 'localhost,', str(play)],
                                    capture_output=True, text=True,
                                    env=dict(os.environ, ANSIBLE_LOCAL_TEMP=str(root / 'local'),
                                             ANSIBLE_REMOTE_TEMP=str(root / 'remote'),
                                             ANSIBLE_HOME=str(root / 'ansible-home')))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            for component in components:
                with self.subTest(component=component):
                    script = (root / (component + '.sh')).read_text()
                    syntax = subprocess.run(['bash', '-n'], input=script,
                                            capture_output=True, text=True)
                    self.assertEqual(syntax.returncode, 0, syntax.stderr)
                    # bash -n can succeed with a warning for an unclosed heredoc!
                    self.assertEqual(syntax.stderr, '')
                    for marker in re.findall(r"<<'(HPC_[A-Z_]+)'", script):
                        self.assertEqual(len(re.findall('^' + marker + '$', script, re.M)), 1)
                    files = re.findall(r"^put_file (\S+) [^\n]*<<'(HPC_[A-Z_]+)'\n(.*?)^\2$",
                                       script, re.M | re.S)
                    self.assertTrue(files)
                    for name, marker, content in files:
                        self.assertNotIn('put_file ', content, name)
                        self.assertNotIn('enable_service ', content, name)
                        self.assertNotIn('HPC_CHANGED', content, name)
                        if name.endswith('.sh'):
                            parsed = subprocess.run(['bash', '-n'], input=content,
                                                    capture_output=True, text=True)
                            self.assertEqual(parsed.returncode, 0, parsed.stderr)
                    if component == 'slurm':
                        conf = next(content for name, _, content in files if name.endswith('/slurm.conf'))
                        self.assertIn('State=UP', conf)
                        self.assertNotIn('HPC_SLURM', conf)
                        self.assertIn('enable_service munge\nenable_service slurmd', script)


if __name__ == '__main__':
    unittest.main()
