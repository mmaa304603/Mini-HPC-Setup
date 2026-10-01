"""ELK rendering and admission checks without installing Elastic or writing system state."""
import base64
import copy
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading
import unittest
import xml.etree.ElementTree as ET

import yaml

from test_components import COMPONENTS, fixture, render

ELK = COMPONENTS / 'elk'
DEFAULTS = yaml.safe_load((ELK / 'defaults/main.yml').read_text())


class ElkTests(unittest.TestCase):
    def values(self):
        values = dict(fixture(), **DEFAULTS)
        values['core_components'].append('elk')
        return values

    def run_tasks(self, tasks, values):
        with tempfile.TemporaryDirectory(prefix='hpc-elk-test-') as directory:
            root = Path(directory)
            play = root / 'test.yml'
            play.write_text(yaml.safe_dump([{'hosts': 'localhost', 'connection': 'local',
                                            'gather_facts': False, 'vars': values, 'tasks': tasks}]))
            return subprocess.run(['ansible-playbook', '-i', 'localhost,', str(play)],
                                  env=dict(os.environ, ANSIBLE_LOCAL_TEMP=str(root / 'local'),
                                           ANSIBLE_REMOTE_TEMP=str(root / 'remote'),
                                           ANSIBLE_HOME=str(root / 'home')),
                                  capture_output=True, text=True, timeout=60)

    def test_apis_stay_on_loopback_and_only_ingestion_opens_on_private_network(self):
        values = self.values()
        for template, setting in [('elasticsearch.yml.j2', 'network.host'),
                                  ('kibana.yml.j2', 'server.host'),
                                  ('logstash.yml.j2', 'api.http.host')]:
            config = yaml.safe_load(render('elk', template, values))
            self.assertEqual(config[setting], '127.0.0.1')
        pipeline = render('elk', 'logstash.conf.j2', values)
        self.assertIn('host => "10.0.0.1"', pipeline)
        self.assertIn('index => "%{[@metadata][hpc_index]}"', pipeline)
        self.assertIn('"hpc-logs-build"', pipeline)
        self.assertNotIn('changeme', pipeline)
        zone = ET.fromstring(render('warewulf', 'cluster-zone.xml.j2', values))
        rule = next(r for r in zone.findall('rule') if r.find('port').get('port') == '5044')
        self.assertEqual(rule.find('source').get('address'), '10.0.0.0/22')
        self.assertFalse(any(p.get('port') in ['9200', '9300', '5601', '9600']
                             for p in zone.iter('port')))
        values['core_components'].remove('elk')
        self.assertNotIn('5044', render('warewulf', 'cluster-zone.xml.j2', values))

    def test_agent_collects_journal_and_slurm_without_recursive_self_logging(self):
        values = self.values()
        config = yaml.safe_load(render('elk', 'filebeat.yml.j2', values))
        inputs = {entry['id']: entry for entry in config['filebeat.inputs']}
        journal, slurm = inputs['hpc-journal'], inputs['hpc-slurm']
        self.assertEqual(journal['id'], 'hpc-journal')
        self.assertEqual(journal['seek'], 'since')
        self.assertEqual(journal['processors'][0]['drop_event']['when.equals.systemd.unit'], 'filebeat.service')
        self.assertEqual(slurm['paths'], ['/var/log/slurm/*.log'])
        self.assertEqual(config['output.logstash']['hosts'], ['10.0.0.1:5044'])
        values['core_components'].remove('slurm')
        self.assertNotIn('hpc-slurm', [entry['id'] for entry in yaml.safe_load(render('elk', 'filebeat.yml.j2', values))['filebeat.inputs']])

    @unittest.skipUnless(shutil.which('filebeat'), 'Filebeat binary is not installed')
    def test_rendered_agent_config_passes_filebeat_validation(self):
        # Use the actual validator: YAML parsing alone misses queue incompatibilities.
        # Isolate runtime paths from the head service's registry and logs.
        with tempfile.TemporaryDirectory(prefix='hpc-filebeat-test-') as directory:
            root = Path(directory)
            config = root / 'filebeat.yml'
            values = self.values()
            for with_slurm in [True, False]:
                with self.subTest(with_slurm=with_slurm):
                    if not with_slurm:
                        values['core_components'].remove('slurm')
                    config.write_text(render('elk', 'filebeat.yml.j2', values))
                    result = subprocess.run([
                        shutil.which('filebeat'), 'test', 'config', '-c', str(config), '-e',
                        '--path.config', str(root), '--path.data', str(root / 'data'),
                        '--path.logs', str(root / 'logs'),
                    ], capture_output=True, text=True, timeout=30)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_local_http_configuration_explicitly_disables_both_tls_layers(self):
        config = yaml.safe_load(render('elk', 'elasticsearch.yml.j2', self.values()))
        self.assertEqual(config['network.host'], '127.0.0.1')
        for setting in ['xpack.security.enabled', 'xpack.security.autoconfiguration.enabled',
                        'xpack.security.http.ssl.enabled', 'xpack.security.transport.ssl.enabled']:
            self.assertIs(config[setting], False)

    def test_failed_start_reports_application_error_and_still_fails_deployment(self):
        tasks = yaml.safe_load((ELK / 'tasks/elasticsearch_service.yml').read_text())
        # Simulate only the system operations; exercise the real rescue/fail path.
        tasks[0]['block'] = [{'ansible.builtin.fail': {'msg': 'TEST_SERVICE_FAILED'}}]
        for task in tasks[0]['rescue']:
            if 'ansible.builtin.command' in task:
                task['ansible.builtin.command']['argv'] = [
                    'printf', '%s', 'TEST_FATAL_SSL_CONFIGURATION']
        tasks.append({'ansible.builtin.debug': {'msg': 'UNREACHABLE_NEXT_PHASE'}})
        result = self.run_tasks(tasks, self.values())
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('TEST_SERVICE_FAILED', result.stdout)
        self.assertIn('TEST_FATAL_SSL_CONFIGURATION', result.stdout)
        self.assertNotIn('UNREACHABLE_NEXT_PHASE', result.stdout)

    def test_restart_handler_uses_the_same_service_helper(self):
        with tempfile.TemporaryDirectory(prefix='hpc-elk-handler-') as directory:
            role = Path(directory) / 'elk'
            shutil.copytree(ELK, role)
            helper = role / 'tasks/elasticsearch_service.yml'
            tasks = yaml.safe_load(helper.read_text())
            tasks[0]['block'] = [{'ansible.builtin.set_fact': {
                'elk_test_states': '{{ elk_test_states | default([]) + [elk_elasticsearch_state] }}'}}]
            helper.write_text(yaml.safe_dump(tasks))
            result = self.run_tasks([
                {'ansible.builtin.include_role': {
                    'name': str(role), 'tasks_from': 'elasticsearch_service'},
                 'vars': {'elk_elasticsearch_state': 'started'}},
                {'ansible.builtin.debug': {'msg': 'Simulated configuration change'},
                 'changed_when': True, 'notify': 'ELK restart Elasticsearch'},
                {'ansible.builtin.meta': 'flush_handlers'},
                {'ansible.builtin.assert': {
                    'that': ["elk_test_states == ['started', 'restarted']"]}},
            ], self.values())
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_actual_memory_admission_accepts_eight_gib_and_rejects_four(self):
        tasks = yaml.safe_load((ELK / 'tasks/preflight.yml').read_text())
        admission = next(t for t in tasks if t['name'].startswith('Require memory'))
        for size, expected in [(8 * 1024, True), (4 * 1024, False)]:
            values = self.values()
            values['elk_meminfo'] = {'content': base64.b64encode(
                f'MemTotal:       {size * 1024} kB\n'.encode()).decode()}
            result = self.run_tasks([admission], values)
            self.assertEqual(result.returncode == 0, expected, result.stdout + result.stderr)

    def test_existing_version_admission_prevents_implicit_migration(self):
        tasks = yaml.safe_load((ELK / 'tasks/preflight.yml').read_text())
        admission = next(t for t in tasks if t['name'].startswith('Refuse implicit'))
        values = self.values()
        for version, expected in [(values['elk_version'], True), ('7.17.0', False)]:
            values['elk_installed'] = {'results': [{'item': 'elasticsearch', 'rc': 0, 'stdout': version}]}
            result = self.run_tasks([admission], values)
            self.assertEqual(result.returncode == 0, expected, result.stdout + result.stderr)

    def test_build_diagnostics_have_their_own_short_retention(self):
        tasks = yaml.safe_load((ELK / 'tasks/index.yml').read_text())
        values = self.values()
        values.update(elk_index_name='hpc-logs-build', elk_index_retention=2, elk_index_rollover='128mb')
        checks = [tasks[0], {'ansible.builtin.assert': {'that': [
            "elk_policy.phases.delete.min_age == '2d'",
            "elk_policy.phases.hot.actions.rollover.max_primary_shard_size == '128mb'",
            "elk_index_template.priority | int == 210",
            "elk_index_template.template.settings.index.lifecycle.rollover_alias == 'hpc-logs-build'",
            "elk_index_template.index_patterns == ['hpc-logs-build-*']",
        ]}}]
        result = self.run_tasks(checks, values)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_bootstrap_sends_rendered_alias_keys_and_skips_existing_alias(self):
        requests = []

        class Handler(BaseHTTPRequestHandler):
            def do_PUT(self):
                body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
                requests.append((self.path, body))
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.end_headers()
                self.wfile.write(b'{"acknowledged": true}')

            def log_message(self, *args):
                pass

        server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        try:
            bootstrap = yaml.safe_load((ELK / 'tasks/index.yml').read_text())[-1]
            for name in ['hpc-logs', 'hpc-logs-build']:
                with self.subTest(name=name):
                    task = copy.deepcopy(bootstrap)
                    uri = task['ansible.builtin.uri']
                    uri['url'] = uri['url'].replace(':9200/', ':' + str(server.server_port) + '/')
                    values = self.values()
                    values['elk_alias'] = {'status': 404}
                    if name != 'hpc-logs':
                        values['elk_index_name'] = name
                    result = self.run_tasks([task], values)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(requests[-1], (
                        '/' + name + '-000001', {'aliases': {name: {'is_write_index': True}}}))
                    count = len(requests)
                    values['elk_alias'] = {'status': 200}
                    result = self.run_tasks([task], values)
                    self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                    self.assertEqual(len(requests), count)
        finally:
            server.shutdown()
            server.server_close()
            thread.join()

    def test_retention_and_index_bootstrap_are_repeatable_without_deleting_data(self):
        # Exercise actual Ansible conditions with canonical Elasticsearch responses.
        tasks = yaml.safe_load((ELK / 'tasks/index.yml').read_text())
        read_policy = {'ansible.builtin.set_fact': {
            'elk_policy_read': {'status': 200, 'json': {'hpc-logs': {'policy': "{{ elk_policy | combine({'phases': {'hot': {'actions': {'rollover': {'min_docs': 1}}}}}, recursive=True) }}"}}},
            'elk_template_read': {'status': 200, 'json': {'index_templates': [{'index_template': "{{ elk_index_template | combine({'created_date_millis': 12345, 'modified_date_millis': 67890}) }}"}]}},
            'elk_alias': {'status': 200},
        }}
        checks = [tasks[0], read_policy]
        for task in tasks:
            if 'when' in task:
                checks.append({'name': 'A matching existing object needs no write',
                               'ansible.builtin.assert': {'that': ['not (' + task['when'] + ')']}})
        checks.append({'ansible.builtin.assert': {'that': [
            "elk_policy.phases.delete.min_age == '7d'",
            "elk_policy.phases.hot.actions.rollover.max_primary_shard_size == '1gb'",
            "elk_index_template.template.settings.index.number_of_replicas == '0'",
        ]}})
        # Also verify the generated token expression executes correctly in Ansible.
        token = yaml.safe_load((ELK / 'tasks/verify_ingestion.yml').read_text())[0]
        checks += [token, {'ansible.builtin.assert': {'that': ["elk_probe is match('^hpc-elk-[0-9a-f]{32}$')"]}}]
        result = self.run_tasks(checks, self.values())
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn('method: DELETE', (ELK / 'tasks/index.yml').read_text())


if __name__ == '__main__':
    unittest.main()
