"""Optional real Logstash parsing test; stdin/stdout only, never contacts ELK."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from test_components import render


@unittest.skipUnless(os.environ.get('HPC_TEST_LOGSTASH') == '1' and Path('/usr/share/logstash/bin/logstash').exists(),
                     'Set HPC_TEST_LOGSTASH=1 to run the installed Logstash parser')
class LogstashEventsTests(unittest.TestCase):
    def test_job_completion_and_structured_payload(self):
        pipeline = render('elk', 'logstash.conf.j2')
        filters = pipeline[pipeline.index('filter {'):pipeline.index('output {')]
        with tempfile.TemporaryDirectory(prefix='hpc-filter-test-') as directory:
            root = Path(directory)
            (root / 'logstash.yml').write_text('api.enabled: false\npipeline.workers: 1\npipeline.ecs_compatibility: v8\n')
            (root / 'pipeline.conf').write_text('input { stdin { codec => json } }\n' + filters +
                '\noutput { stdout { codec => json_lines } }\n')
            events = [
                {'log': {'file': {'path': '/var/log/slurm/job-completion.log'}},
                 'message': 'JobId=42 UserId=jay(1000) GroupId=jay(1000) Name=unique-probe JobState=COMPLETED ExitCode=0:0 NodeList=cpu01'},
                {'host': {'name': 'cpu01'}, 'hpc_payload': {
                    '@timestamp': '2026-09-30T12:00:00+00:00', 'host': {'name': 'forged'},
                    'event': {'dataset': 'hpc.lmod', 'action': 'load', 'outcome': 'success'},
                    'hpc': {'module': {'name': 'hdf5/test'}}, 'message': 'loaded hdf5'}},
            ]
            result = subprocess.run(['/usr/share/logstash/bin/logstash', '--path.settings', directory,
                '--path.data', str(root/'data'), '--path.logs', str(root/'logs'), '-f', str(root/'pipeline.conf')],
                input=''.join(json.dumps(event)+'\n' for event in events), text=True, capture_output=True,
                timeout=300, env=dict(os.environ, LS_JAVA_OPTS='-Xms256m -Xmx256m'))
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            rows = []
            for line in result.stdout.splitlines():
                try:
                    row = json.loads(line)
                    if isinstance(row, dict) and 'event' in row:
                        rows.append(row)
                except ValueError:
                    pass
            self.assertEqual(len(rows), 2, result.stdout + result.stderr)
            job = next(row for row in rows if row['event']['dataset'] == 'hpc.slurm.job')
            self.assertEqual(job['hpc']['slurm']['Name'], 'unique-probe')
            self.assertEqual(job['hpc']['slurm']['ExitCode'], '0:0')
            module = next(row for row in rows if row['event']['dataset'] == 'hpc.lmod')
            self.assertEqual(module['host']['name'], 'cpu01')
            self.assertEqual(module['message'], 'loaded hdf5')
            self.assertEqual(module['@timestamp'], '2026-09-30T12:00:00.000Z')
            self.assertIn('ingested', module['event'])
