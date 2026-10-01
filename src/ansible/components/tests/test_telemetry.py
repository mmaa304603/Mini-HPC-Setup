"""Observability tests: bounded capture, exit codes, no_log, hooks, and image configuration."""
import importlib.util
from importlib.machinery import SourceFileLoader
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from test_components import COMPONENTS, fixture, render

SCRIPT = COMPONENTS / 'elk/templates/telemetry.py.j2'
loader = SourceFileLoader('telemetry', str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
TELEMETRY = importlib.util.module_from_spec(spec)
loader.exec_module(TELEMETRY)
CALLBACK_PATH = COMPONENTS.parent / 'core/roles/hpc_core/callback_plugins/hpc_events.py'
spec = importlib.util.spec_from_file_location('hpc_events', CALLBACK_PATH)
CALLBACK = importlib.util.module_from_spec(spec)
spec.loader.exec_module(CALLBACK)


class TelemetryTests(unittest.TestCase):
    def test_command_exit_and_bounded_failure_capture_with_redaction(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            stage = root / 'stage'
            stage.mkdir()
            output = root / 'events.jsonl'
            code = ("from pathlib import Path; import sys; "
                    "Path(sys.argv[1]).write_text('x'*300000+' password=hidden'); "
                    "print('token=hidden'); print('y'*300000); sys.exit(7)")
            result = subprocess.run([sys.executable, str(SCRIPT), '--output', str(output),
                'run', '--action', 'test', '--stage', str(stage), '--spec', 'password=hidden',
                '--', sys.executable, '-c', code, str(stage / 'spack-build-out.txt')],
                capture_output=True, timeout=20)
            self.assertEqual(result.returncode, 7)
            records = [json.loads(line) for line in output.read_text().splitlines()]
            self.assertEqual(records[0]['event']['action'], 'test-start')
            self.assertEqual(records[1]['hpc']['process']['exit_code'], 7)
            self.assertLess(output.stat().st_size, 700000)
            self.assertNotIn('hidden', output.read_text())
            self.assertTrue(any(r['hpc'].get('diagnostic', {}).get('truncated') for r in records))
            self.assertIn('y' * 100, result.stdout.decode())

    def test_logging_failure_does_not_break_successful_component_command(self):
        result = subprocess.run([sys.executable, str(SCRIPT), '--output', '/nonexistent/hpc-test/events',
            'run', '--action', 'test', '--', sys.executable, '-c', 'print("success")'],
            capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0)
        self.assertIn('success', result.stdout)
        self.assertIn('telemetry write failed', result.stderr)

    def test_rotation_retains_three_files_and_refuses_symlink_write(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / 'events.jsonl'
            with patch.object(TELEMETRY, 'MAX_FILE', 10):
                for index in range(8):
                    TELEMETRY.append(path, {'index': index})
            files = sorted(p.name for p in Path(directory).iterdir())
            self.assertEqual(files, ['events.jsonl', 'events.jsonl.1', 'events.jsonl.2', 'events.jsonl.lock'])
            victim = Path(directory) / 'victim'
            victim.write_text('keep')
            link = Path(directory) / 'link'
            link.symlink_to(victim)
            with self.assertRaises(OSError):
                TELEMETRY.append(link, {'bad': True})
            self.assertEqual(victim.read_text(), 'keep')

    def test_callback_never_emits_no_log_results_or_arguments(self):
        with tempfile.TemporaryDirectory() as directory:
            callback = CALLBACK.CallbackModule()
            callback.spool = Path(directory) / 'callback.jsonl'
            callback.spool.touch()
            callback.run_id = 'test'
            task = SimpleNamespace(no_log=True, action='command', _uuid='test', get_name=lambda: 'secret task')
            callback.write(task, 'failure', result={'stdout': 'secret-123'})
            task.no_log = False
            callback.write(task, 'failure', result={'_ansible_no_log': True, 'stdout': 'secret-123'})
            self.assertEqual(callback.spool.read_text(), '')
            callback.write(task, 'failure', result={'stderr': 'password=hidden', 'invocation': {'secret': 'secret-123'}})
            text = callback.spool.read_text()
            self.assertNotIn('hidden', text)
            self.assertNotIn('secret-123', text)
            self.assertNotIn('invocation', text)
            self.assertIn('[REDACTED]', text)

    def test_cpu_snapshot_config_does_not_run_head_commands(self):
        values = fixture()
        values['elk_image'] = True
        config = json.loads(render('elk', 'telemetry.json.j2', values))
        self.assertFalse(config['head'])
        self.assertNotIn('elasticsearch', config['services'])
        self.assertIn('slurmd', config['services'])

    @unittest.skipUnless(shutil.which('lua'), 'Lua is not installed')
    def test_lmod_hooks_escape_values_and_survive_syslog_failure(self):
        script = render('lmod', 'SitePackage.lua.j2')
        harness = '''
local hooks = {}
package.preload['Hook'] = function() return {register=function(k,v) hooks[k]=v end} end
local messages = {}
package.preload['posix'] = function() return {
 openlog=function() end, closelog=function() end,
 syslog=function(level,msg) table.insert(messages,msg) end} end
'''
        invocation = '''
hooks.load({modFullName='test/"quoted\\nmodule'})
hooks.unload({modFullName='test/"quoted\\nmodule'})
for _,msg in ipairs(messages) do print(msg) end
package.loaded.posix.syslog = function() error('unavailable') end
hooks.load({modFullName='still-works'})
'''
        result = subprocess.run(['lua', '-'], input=harness + script + invocation,
                                text=True, capture_output=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        records = [json.loads(line) for line in result.stdout.splitlines()]
        self.assertEqual([r['event']['action'] for r in records], ['load', 'unload'])
        self.assertEqual(records[0]['hpc']['module']['name'], 'test/"quoted\nmodule')

    @unittest.skipUnless(Path('/usr/share/lmod/lmod/init/bash').exists(), 'Lmod is not installed')
    def test_real_lmod_calls_both_hooks(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / 'modules').mkdir()
            (root / 'modules/test.lua').write_text('setenv("HPC_TEST_MODULE", "yes")\n')
            site = root / 'site'
            site.mkdir()
            # Exercise the installed Lmod hook API, redirecting syslog only to a temp file.
            stub = """local p=require('posix')
local api=type(p.syslog)=='table' and p.syslog or p
api.openlog=function() end
api.closelog=function() end
api.syslog=function(_,message)
 local f=assert(io.open(os.getenv('HPC_TEST_EVENTS'),'a')); f:write(message,'\\n'); f:close()
end
"""
            (site / 'SitePackage.lua').write_text(stub + render('lmod', 'SitePackage.lua.j2'))
            result = subprocess.run(['bash', '--noprofile', '--norc', '-c',
                'set -e; source /usr/share/lmod/lmod/init/bash; module load test; module unload test'],
                env=dict(os.environ, HOME=str(root), MODULEPATH=str(root / 'modules'),
                         LMOD_PACKAGE_PATH=str(site), HPC_TEST_EVENTS=str(root / 'events'),
                         HPC_LOG_PROBE='actual-lmod', LMOD_IGNORE_CACHE='yes'),
                text=True, capture_output=True, timeout=30)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            rows = [json.loads(line) for line in (root / 'events').read_text().splitlines()]
            self.assertEqual([r['event']['action'] for r in rows], ['load', 'unload'])
            self.assertEqual(rows[0]['hpc']['probe']['id'], 'actual-lmod')

    def test_completion_logging_is_optional(self):
        values = fixture()
        self.assertNotIn('JobCompType', render('slurm', 'slurm.conf.j2', values))
        values['core_components'].append('elk')
        self.assertIn('JobCompType=jobcomp/filetxt', render('slurm', 'slurm.conf.j2', values))


if __name__ == '__main__':
    unittest.main()
