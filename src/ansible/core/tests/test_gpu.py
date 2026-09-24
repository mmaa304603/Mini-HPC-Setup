"""GPU entrypoint safety and sequencing; never connects to cluster machines."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

import yaml


CORE = Path(__file__).resolve().parents[1]
ANSIBLE = CORE.parent
JETSON = ANSIBLE / 'components/jetson'


class GpuWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='hpc-gpu-tests-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.inventory = self.root / 'hosts.yml'
        self.nodes = {'all': {'children': {
            'headnode': {'hosts': {'head': {'ansible_host': '192.0.2.1'}}},
            'cpu_nodes': {'hosts': {'cpu1': {'ansible_host': '192.0.2.2'}}},
            'gpu_nodes': {'hosts': {'gpu1': {
                'ansible_host': '192.0.2.3', 'cluster_architecture': 'aarch64',
                'ansible_user': 'jetson', 'ansible_connection': 'ssh'}}},
        }}}
        self.write(self.inventory, self.nodes)
        self.env = dict(os.environ, ANSIBLE_CONFIG=str(ANSIBLE / 'ansible.cfg'),
                        ANSIBLE_HOME=str(self.root / 'home'),
                        ANSIBLE_LOCAL_TEMP=str(self.root / 'local'),
                        ANSIBLE_REMOTE_TEMP=str(self.root / 'remote'),
                        ANSIBLE_BECOME_ASK_PASS='False', ANSIBLE_NOCOLOR='1')

    def write(self, path, value):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(yaml.safe_dump(value, sort_keys=False))

    def run_play(self, *args, playbook=None, **variables):
        result = subprocess.run(
            ['ansible-playbook', '-i', str(self.inventory),
             str(playbook or CORE / 'playbooks/gpu.yml'), '-e', json.dumps(variables), *args],
            env=self.env, capture_output=True, text=True, timeout=60)
        return result.returncode, result.stdout + result.stderr

    def test_actual_plan_is_offline_even_without_login_configured(self):
        del self.nodes['all']['children']['gpu_nodes']['hosts']['gpu1']['ansible_user']
        self.write(self.inventory, self.nodes)
        rc, output = self.run_play('--check', gpu_action='plan')
        self.assertEqual(rc, 0, output)
        self.assertIn('changed=0', output)
        self.assertNotIn('unreachable=1', output)
        self.assertNotIn('Gather the head operating system facts', output)

    def test_invalid_modes_and_partial_execution_stop_before_connections(self):
        for args, variables in [
            ([], {'gpu_action': 'typo'}), (['--check'], {}),
            (['--tags', 'jetson'], {}), (['--limit', 'head'], {}),
            (['--skip-tags', 'unused'], {}),
        ]:
            with self.subTest(args=args, variables=variables):
                rc, output = self.run_play(*args, **variables)
                self.assertNotEqual(rc, 0, output)
                self.assertNotIn('Inspect the setup handoff files', output)

    def test_unsafe_gpu_inventory_stops_before_head_access(self):
        gpu = self.nodes['all']['children']['gpu_nodes']['hosts']['gpu1']
        for field, value in [('ansible_connection', 'local'),
                             ('ansible_user', 'root'), ('cluster_architecture', 'x86_64')]:
            with self.subTest(field=field):
                original = gpu[field]
                gpu[field] = value
                self.write(self.inventory, self.nodes)
                rc, output = self.run_play(gpu_action='preflight')
                self.assertNotEqual(rc, 0, output)
                self.assertNotIn('Inspect the setup handoff files', output)
                gpu[field] = original

    def test_missing_head_handoff_stops_before_gpu_access(self):
        self.nodes['all']['children']['headnode']['hosts']['head']['ansible_connection'] = 'local'
        self.write(self.inventory, self.nodes)
        rc, output = self.run_play(gpu_action='preflight', ansible_become=False,
                                   core_setup_complete_flag=str(self.root / 'missing-flag'),
                                   core_setup_file=str(self.root / 'missing-setup.yml'))
        self.assertNotEqual(rc, 0, output)
        self.assertIn('Complete setup first', output)
        self.assertNotIn('Wait for Jetson SSH and Python', output)

    def test_network_guard_rejects_wrong_prefix_or_external_gateway(self):
        task = yaml.safe_load((JETSON / 'tasks/network_check.yml').read_text())[-1]
        play = self.root / 'network.yml'
        for prefix, gateway, success in [(22, '10.0.0.1', True),
                                         (24, '10.0.0.1', False),
                                         (22, '192.168.1.1', False)]:
            variables = {
                'gpu_cluster': {'network': {'prefix': 22}, 'head': {'address': '10.0.0.1'}},
                'ansible_host': '10.0.2.4',
                'jetson_addresses': {'stdout': json.dumps([
                    {'addr_info': [{'local': '10.0.2.4', 'prefixlen': prefix}]}])},
                'jetson_routes': {'stdout': json.dumps([{'gateway': gateway}])},
            }
            self.write(play, [{'hosts': 'gpu_nodes', 'gather_facts': False,
                               'vars': variables, 'tasks': [task]}])
            rc, output = self.run_play(playbook=play)
            self.assertEqual(rc == 0, success, output)

    def recording_workflow(self):
        roles = self.root / 'roles'
        shutil.copytree(CORE / 'roles/hpc_gpu', roles / 'hpc_gpu')
        # Substitute only live head/connection checks with recording tasks.
        path = roles / 'hpc_gpu/tasks/head.yml'
        tasks = yaml.safe_load(path.read_text())
        replacements = {
            'Read and validate the existing head contract': {
                'ansible.builtin.set_fact': {'core_cluster': {'head': {'name': 'head'}}}},
            'Require the existing head time service before changing the Jetson': {
                'ansible.builtin.debug': {'msg': 'TEST_HEAD_TIME'}},
            'Require the head clock to be synchronized': {
                'ansible.builtin.debug': {'msg': 'TEST_HEAD_CLOCK'}},
        }
        for index, task in enumerate(tasks):
            if task['name'] in replacements:
                tasks[index] = dict(name=task['name'], when=task['when'], **replacements[task['name']])
        self.write(path, tasks)
        path = roles / 'hpc_gpu/tasks/main.yml'
        tasks = yaml.safe_load(path.read_text())
        block = tasks[1]['block']
        block[1] = {'name': 'Simulated SSH', 'ansible.builtin.debug': {'msg': 'TEST_GPU_SSH'}}
        self.write(path, tasks)
        components = self.root / 'components'
        for phase in ['preflight', 'deploy', 'verify']:
            task = {'name': 'Record ' + phase,
                    'ansible.builtin.debug': {'msg': 'GPU_PHASE::' + phase}}
            if phase == 'deploy':
                task.update(changed_when=True, notify='Record GPU handler')
            self.write(components / f'jetson/tasks/{phase}.yml', [task])
        self.write(components / 'jetson/handlers/main.yml', [
            {'name': 'Record GPU handler', 'ansible.builtin.debug': {'msg': 'GPU_HANDLER'}}])
        config = self.root / 'ansible.cfg'
        config.write_text('[defaults]\nroles_path = ' + str(roles) + '\n')
        self.env['ANSIBLE_CONFIG'] = str(config)
        play = self.root / 'gpu.yml'
        shutil.copyfile(CORE / 'playbooks/gpu.yml', play)
        return play, components

    def test_deploy_order_handlers_and_failure_propagation(self):
        play, components = self.recording_workflow()
        rc, output = self.run_play(playbook=play, gpu_components_dir=str(components))
        self.assertEqual(rc, 0, output)
        phases = ['GPU_PHASE::preflight', 'GPU_PHASE::deploy', 'GPU_HANDLER', 'GPU_PHASE::verify',
                  'initialization and local CUDA acceptance passed']
        self.assertEqual(sorted(output.index(p) for p in phases), [output.index(p) for p in phases])
        self.write(components / 'jetson/tasks/deploy.yml', [
            {'ansible.builtin.fail': {'msg': 'GPU_BASELINE_FAILED'}}])
        rc, output = self.run_play(playbook=play, gpu_components_dir=str(components))
        self.assertNotEqual(rc, 0, output)
        self.assertNotIn('GPU_PHASE::verify', output)
        self.assertNotIn('initialization and local CUDA acceptance passed', output)

    def test_preflight_and_verify_never_install(self):
        play, components = self.recording_workflow()
        for action in ['preflight', 'verify']:
            with self.subTest(action=action):
                rc, output = self.run_play(playbook=play, gpu_components_dir=str(components), gpu_action=action)
                self.assertEqual(rc, 0, output)
                self.assertNotIn('GPU_PHASE::deploy', output)
                self.assertNotIn('GPU_HANDLER', output)
                self.assertEqual('GPU_PHASE::verify' in output, action == 'verify')

    def test_identity_collision_assertion_rejects_existing_uid_owner(self):
        task = yaml.safe_load((JETSON / 'tasks/identities_check.yml').read_text())[1]
        play = self.root / 'identity.yml'
        facts = {'getent_passwd': {}, 'getent_group': {}}
        variables = {'gpu_cluster': {'service_users': [
            {'name': 'munge', 'group': 'munge', 'uid': 959, 'gid': 967}]},
            'ansible_facts': facts}
        for occupied in [False, True]:
            if occupied:
                facts['getent_passwd']['existing'] = ['x', '959', '1000', '', '/', '/bin/bash']
            self.write(play, [{'hosts': 'gpu_nodes', 'gather_facts': False,
                               'vars': variables, 'tasks': [task]}])
            rc, output = self.run_play(playbook=play)
            self.assertEqual(rc == 0, not occupied, output)


class CudaAcceptanceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        spec = importlib.util.spec_from_file_location('cuda_check', JETSON / 'files/cuda_check.py')
        cls.module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(cls.module)

    def driver(self, result=42, fail=None):
        calls = []

        class Driver:
            def __getattr__(self, name):
                def function(*args):
                    calls.append(name)
                    if name == fail:
                        return 999
                    if name in ['cuDeviceGetCount', 'cuCtxCreate_v2', 'cuModuleLoadData', 'cuMemAlloc_v2']:
                        args[0]._obj.value = 1
                    elif name == 'cuDeviceGetName':
                        args[0].value = b'Orin'
                    elif name == 'cuMemcpyDtoH_v2':
                        args[0]._obj.value = result
                    return 0
                setattr(self, name, function)
                return function

        return Driver(), calls

    def test_kernel_result_is_checked_and_resources_are_released(self):
        for result in [42, 0]:
            driver, calls = self.driver(result=result)
            if result == 42:
                self.assertEqual(self.module.check_cuda(driver)['status'], 'passed')
            else:
                with self.assertRaisesRegex(RuntimeError, 'expected 42'):
                    self.module.check_cuda(driver)
            self.assertIn('cuLaunchKernel', calls)
            self.assertEqual(calls[-3:], ['cuMemFree_v2', 'cuModuleUnload', 'cuCtxDestroy_v2'])

    def test_driver_failure_is_not_reported_as_success(self):
        driver, calls = self.driver(fail='cuLaunchKernel')
        with self.assertRaisesRegex(RuntimeError, 'cuLaunchKernel failed'):
            self.module.check_cuda(driver)
        self.assertEqual(calls[-3:], ['cuMemFree_v2', 'cuModuleUnload', 'cuCtxDestroy_v2'])

    def test_cleanup_failure_still_releases_the_context(self):
        driver, calls = self.driver(fail='cuMemFree_v2')
        with self.assertRaisesRegex(RuntimeError, 'cuMemFree_v2 failed'):
            self.module.check_cuda(driver)
        self.assertEqual(calls[-1], 'cuCtxDestroy_v2')
