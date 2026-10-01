"""Allowlisted, bounded deployment events; never serialize module arguments or secrets."""
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import tempfile
import uuid
from ansible.plugins.callback import CallbackBase

DOCUMENTATION = '''
name: hpc_events
type: notification
short_description: Collect bounded core deployment task diagnostics
version_added: "1.0"
requirements:
  - Enable with callbacks_enabled
'''


class CallbackModule(CallbackBase):
    CALLBACK_VERSION = 2.0
    CALLBACK_TYPE = 'notification'
    CALLBACK_NAME = 'hpc_events'
    CALLBACK_NEEDS_ENABLED = True

    def v2_playbook_on_start(self, playbook):
        self.spool = None
        if Path(playbook._file_name).name not in ['site.yml', 'verify.yml']:
            return
        fd, name = tempfile.mkstemp(prefix='hpc-events-', suffix='.jsonl')
        os.close(fd)
        self.spool = Path(name)
        self.run_id = uuid.uuid4().hex
        os.environ['HPC_EVENT_SPOOL'] = name
        os.environ['HPC_EVENT_RUN_ID'] = self.run_id

    def write(self, task, outcome, host='', result=None):
        if not getattr(self, 'spool', None):
            return
        result = result or {}
        # Templated no_log is treated conservatively; never record args/results for it.
        if task.no_log or result.get('_ansible_no_log') or task.action.endswith('set_fact'):
            return
        def clean(text):
            text = re.sub(r'(?i)((?:password|token|secret|api[_-]?key|authorization)\s*[=:]\s*)[^\s,;]+',
                          r'\1[REDACTED]', str(text))
            return re.sub(r'(https?://)[^/@\s]+:[^/@\s]+@', r'\1[REDACTED]@', text)[:4096]
        details = {'deployment': {'id': self.run_id},
                   'task': {'name': clean(task.get_name()), 'id': str(task._uuid),
                            'action': task.action, 'target': host},
                   'changed': bool(result.get('changed', False))}
        if outcome == 'failure':
            details['diagnostic'] = {k: clean(result[k]) for k in ['msg', 'stderr', 'stdout', 'rc'] if k in result}
        entry = {'@timestamp': datetime.now(timezone.utc).isoformat(),
                 'event': {'dataset': 'hpc.deployment', 'action': 'task', 'outcome': outcome},
                 'message': clean(task.get_name()), 'hpc': details}
        try:
            if self.spool.stat().st_size > 2 * 1024 * 1024:
                # Preserve recent failure evidence; mark the dropped history explicitly.
                lines = self.spool.read_bytes().splitlines(keepends=True)
                kept = b''.join(lines)[-1024 * 1024:].split(b'\n', 1)[-1]
                self.spool.write_bytes(kept)
                entry['hpc']['history_truncated'] = True
            with self.spool.open('a') as stream:
                stream.write(json.dumps(entry) + '\n')
        except OSError:
            self._display.warning('Unable to record HPC deployment telemetry')

    def v2_playbook_on_task_start(self, task, is_conditional):
        self.write(task, 'unknown')

    def v2_runner_on_ok(self, result):
        self.write(result._task, 'success', result._host.get_name(), result._result)

    def v2_runner_on_failed(self, result, ignore_errors=False):
        self.write(result._task, 'failure', result._host.get_name(), result._result)

    def v2_runner_on_unreachable(self, result):
        self.write(result._task, 'failure', result._host.get_name(), result._result)

    def v2_runner_on_skipped(self, result):
        self.write(result._task, 'unknown', result._host.get_name(), {'msg': 'skipped'})

    def v2_playbook_on_stats(self, stats):
        # Core copies the spool under its deployment lock, including rescued failures.
        if getattr(self, 'spool', None):
            self.spool.unlink(missing_ok=True)
        os.environ.pop('HPC_EVENT_SPOOL', None)
        os.environ.pop('HPC_EVENT_RUN_ID', None)
