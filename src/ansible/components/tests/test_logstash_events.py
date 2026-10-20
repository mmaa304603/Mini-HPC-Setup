"""Optional real Logstash parsing test; stdin/stdout only, never contacts ELK."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from test_components import render, COMPONENTS


@unittest.skipUnless(os.environ.get('HPC_TEST_LOGSTASH') == '1' and Path('/usr/share/logstash/bin/logstash').exists(),
                     'Set HPC_TEST_LOGSTASH=1 to run the installed Logstash parser')
class LogstashEventsTests(unittest.TestCase):
    def test_job_completion_and_structured_payload(self):
        pipeline = render('elk', 'logstash.conf.j2')
        filters = pipeline[pipeline.index('filter {'):pipeline.index('output {')]
        filters = filters.replace('/etc/logstash/hpc-normalize.rb',
                                  str(COMPONENTS / 'elk/files/normalize.rb'))
        with tempfile.TemporaryDirectory(prefix='hpc-filter-test-') as directory:
            root = Path(directory)
            (root / 'logstash.yml').write_text('api.enabled: false\npipeline.workers: 1\npipeline.ecs_compatibility: v8\n')
            (root / 'pipeline.conf').write_text('input { stdin { codec => json } }\n' + filters +
                '\noutput { stdout { codec => json_lines } }\n')
            events = [
                {'log': {'file': {'path': '/var/log/slurm/job-completion.log'}},
                 'host': {'name': 'head'}, '@metadata': {'_id': 'job-source'},
                 'message': 'JobId=42_3 UserId=jay(1000) GroupId=jay(1000) Name=unique-probe JobState=COMPLETED ExitCode=0:0 NodeList=cpu01 Partition=cpu'},
                {'host': {'name': 'cpu01'}, 'hpc_payload': {
                    '@timestamp': '2026-09-30T12:00:00+00:00', 'host': {'name': 'forged'},
                    'event': {'id': 'source-uuid', 'dataset': 'hpc.lmod', 'action': 'load', 'outcome': 'success'},
                    'service': {'name': 'lmod'}, 'trace': {'id': 'a' * 32}, 'span': {'id': 'b' * 16},
                    'hpc': {'module': {'name': 'hdf5/test'}, 'cluster': {'id': 'forged'}},
                    'message': 'loaded hdf5'}},
                {'host': {'name': 'cpu01'}, 'event': {'dataset': 'hpc.journal'},
                 'systemd': {'unit': 'sshd.service'}, 'log': {'syslog': {'severity': {'code': 3}}},
                 '@metadata': {'_id': 'journal-source'}, 'message': 'authentication failed',
                 'trace': {'id': 'not-a-trace'}},
            ]
            # Retries of one event must retain identity, even after ingestion time changes.
            events.append(events[1])
            events.append(dict(events[2], **{'@metadata': {'_id': 'different-journal-source'}}))
            try:
                result = subprocess.run(['/usr/share/logstash/bin/logstash', '--path.settings', directory,
                    '--path.data', str(root/'data'), '--path.logs', str(root/'logs'), '-f', str(root/'pipeline.conf')],
                    input=''.join(json.dumps(event)+'\n' for event in events), text=True, capture_output=True,
                    timeout=int(os.environ.get('HPC_TEST_LOGSTASH_TIMEOUT', '300')),
                    env=dict(os.environ, LS_JAVA_OPTS='-Xms512m -Xmx512m'))
            except subprocess.TimeoutExpired as error:
                self.fail('Logstash timed out:\n' +
                          (error.stdout or b'').decode(errors='replace') +
                          (error.stderr or b'').decode(errors='replace'))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            rows = []
            for line in result.stdout.splitlines():
                try:
                    row = json.loads(line)
                    if isinstance(row, dict) and 'event' in row:
                        rows.append(row)
                except ValueError:
                    pass
            self.assertEqual(len(rows), 5, result.stdout + result.stderr)
            for row in rows:
                self.assertEqual(row['hpc']['schema']['version'], '1.0.0')
                self.assertEqual(row['hpc']['cluster']['id'], 'mini-hpc')
                self.assertRegex(row['event']['id'], r'^[0-9a-f]{64}$')
                self.assertNotIn('_rubyexception', row.get('tags', []))
            job = next(row for row in rows if row['event']['dataset'] == 'hpc.slurm.job')
            self.assertEqual(job['hpc']['slurm']['Name'], 'unique-probe')
            self.assertEqual(job['hpc']['slurm']['ExitCode'], '0:0')
            self.assertEqual(job['hpc']['job']['id'], '42_3')
            self.assertEqual(job['hpc']['partition'], 'cpu')
            self.assertEqual(job['event']['outcome'], 'success')
            self.assertEqual(job['service']['name'], 'slurmctld')
            module = next(row for row in rows if row['event']['dataset'] == 'hpc.lmod')
            self.assertEqual(module['host']['name'], 'cpu01')
            self.assertEqual(module['message'], 'loaded hdf5')
            self.assertEqual(module['@timestamp'], '2026-09-30T12:00:00.000Z')
            self.assertIn('ingested', module['event'])
            self.assertEqual(module['trace']['id'], 'a' * 32)
            self.assertEqual(module['span']['id'], 'b' * 16)
            modules = [r for r in rows if r['event']['dataset'] == 'hpc.lmod']
            self.assertEqual(modules[0]['event']['id'], modules[1]['event']['id'])
            journals = [r for r in rows if r['event']['dataset'] == 'hpc.journal']
            self.assertNotEqual(journals[0]['event']['id'], journals[1]['event']['id'])
            self.assertEqual(journals[0]['service']['name'], 'sshd')
            self.assertEqual(journals[0]['log']['level'], 'error')
            self.assertIn('_hpc_invalid_trace_id', journals[0]['tags'])
            self.assertFalse(journals[0].get('trace', {}).get('id'))
