"""Checkpoint storage safety and real Ansible resume against recording roles."""
import importlib.util
import json
import os
import re
import shutil
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

import yaml
import test_orchestration as orchestration


MODULE_PATH = orchestration.CORE / 'roles/hpc_core/library/hpc_core_checkpoint.py'
spec = importlib.util.spec_from_file_location('checkpoint_module', MODULE_PATH)
checkpoint = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checkpoint)

SLURM_FACTS = {'slurm_rpm_release': '24.05-1', 'slurm_controller_hostname': 'head',
               'slurm_job_identity': {'name': 'jay', 'group': 'jay', 'uid': 1000, 'gid': 1000}}
LMOD_FACTS = {'lmod_rpm_release': '8.7-1', 'hpc_spack_module_test': {
    'module_path': '/opt/spack/modules/lmod/Core', 'name': 'hdf5/test',
    'prefix': '/opt/spack/opt/spack/hdf5-test', 'command': ['h5dump', '-V']}}


class ReceiptTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.directory = Path(self.temp.name) / 'checkpoints'
        self.plan = [{'phase': phase, 'fingerprint': str(i) * 64} for i, phase in
                     enumerate(['warewulf-head', 'slurm-head', 'spack-head'], 1)]

    def call(self, **kwargs):
        args = dict(directory=str(self.directory), state='prepare', plan=self.plan,
                    resume=True, phase='', facts={})
        args.update(kwargs)
        return checkpoint.execute(args)

    def save_all(self):
        self.call()
        for item in self.plan:
            self.call(state='save', phase=item['phase'],
                      facts=SLURM_FACTS if item['phase'] == 'slurm-head' else {})

    def test_only_matching_prefix_is_restored_and_suffix_removed_before_execution(self):
        self.save_all()
        self.plan[1]['fingerprint'] = 'a' * 64
        result = self.call()
        self.assertEqual(result['skipped'], ['warewulf-head'])
        self.assertEqual(result['restored_facts'], {})
        self.assertFalse((self.directory / 'spack-head.json').exists())
        # A later retry cannot revive the formerly successful suffix.
        self.assertEqual(self.call()['skipped'], ['warewulf-head'])

    def test_normal_deploy_invalidates_all_previous_successes(self):
        self.save_all()
        self.assertEqual(self.call(resume=False)['skipped'], [])
        self.assertEqual(list(self.directory.glob('*.json')), [])

    def test_numeric_identity_strings_are_normalized_without_mutating_inputs(self):
        facts = dict(SLURM_FACTS, slurm_job_identity=dict(SLURM_FACTS['slurm_job_identity'], uid='1000', gid='100'))
        self.call(state='save', phase='slurm-head', facts=facts)
        path = self.directory / 'slurm-head.json'
        receipt = json.loads(path.read_text())
        self.assertEqual(receipt['facts']['slurm_job_identity']['uid'], 1000)
        self.assertEqual(receipt['facts']['slurm_job_identity']['gid'], 100)
        self.assertEqual(facts['slurm_job_identity']['uid'], '1000')
        # Readers also normalize compatible receipts written with numeric strings.
        receipt['facts'] = facts
        path.write_text(json.dumps(receipt))
        loaded = checkpoint.read_receipt(str(path), self.plan[1])
        self.assertEqual(loaded['facts']['slurm_job_identity']['uid'], 1000)

    def test_invalid_identity_values_still_cannot_create_receipts(self):
        for key in ('uid', 'gid'):
            for value in (True, False, 1000.5, '1000.5', '-1', 'abc', '', None, [], {}):
                with self.subTest(key=key, value=value):
                    identity = dict(SLURM_FACTS['slurm_job_identity'], **{key: value})
                    with self.assertRaises(ValueError):
                        self.call(state='save', phase='slurm-head',
                                  facts=dict(SLURM_FACTS, slurm_job_identity=identity))
        with self.assertRaises(ValueError):
            self.call(state='save', phase='slurm-head', facts=dict(SLURM_FACTS,
                slurm_job_identity=dict(SLURM_FACTS['slurm_job_identity'], uid='0')))
        self.assertFalse((self.directory / 'slurm-head.json').exists())

    def test_corrupt_receipt_reruns_suffix(self):
        self.save_all()
        (self.directory / 'slurm-head.json').write_text('')
        self.assertEqual(self.call()['skipped'], ['warewulf-head'])

    def test_required_facts_are_restored_but_extra_facts_are_rejected(self):
        self.save_all()
        self.assertEqual(self.call()['restored_facts'], SLURM_FACTS)
        with self.assertRaises(ValueError):
            self.call(state='save', phase='slurm-head', facts=dict(SLURM_FACTS, munge_key='secret'))
        with self.assertRaises(ValueError):
            self.call(state='save', phase='slurm-head', facts={})

    def test_receipt_symlinks_and_public_permissions_fail_closed(self):
        self.save_all()
        path = self.directory / 'warewulf-head.json'
        path.chmod(0o644)
        with self.assertRaises(ValueError):
            self.call()
        path.unlink()
        target = Path(self.temp.name) / 'target'
        target.write_text('untouched')
        path.symlink_to(target)
        with self.assertRaises(ValueError):
            self.call(resume=False)
        self.assertEqual(target.read_text(), 'untouched')


class ResumeTests(unittest.TestCase):
    setUp = orchestration.OrchestrationTests.setUp
    write = orchestration.OrchestrationTests.write
    run_play = orchestration.OrchestrationTests.run_play

    def test_real_slurm_identity_task_can_be_checkpointed_and_restored(self):
        self.enable_checkpoints()
        tasks = yaml.safe_load((orchestration.ANSIBLE / 'components/slurm/tasks/head.yml').read_text())
        identity_task = next(t for t in tasks if t['name'] == 'Record only the selected job identity for the image')
        plan = [{'phase': 'slurm-head', 'fingerprint': 'a' * 64}]
        self.write(self.role / 'tasks/main.yml', [
            {'ansible.builtin.set_fact': {
                'slurm_verify_user': 'jay', 'slurm_job_user_record': ['x', '1000', '1000'],
                'slurm_primary_group': {'ansible_facts': {'getent_group': {'jay': ['x', '1000', '']}}},
                'slurm_rpm_release': '24.05-1', 'slurm_controller_hostname': 'head'}},
            identity_task,
            {'hpc_core_checkpoint': {'directory': str(self.receipts), 'state': 'save', 'plan': plan,
                'phase': 'slurm-head', 'facts': "{{ {'slurm_rpm_release': slurm_rpm_release, 'slurm_controller_hostname': slurm_controller_hostname, 'slurm_job_identity': slurm_job_identity} }}"}},
            {'hpc_core_checkpoint': {'directory': str(self.receipts), 'state': 'prepare', 'plan': plan,
                                    'resume': True}, 'register': 'restored'},
            {'ansible.builtin.assert': {'that': [
                "restored.skipped == ['slurm-head']",
                'restored.restored_facts.slurm_job_identity.uid == 1000',
                'restored.restored_facts.slurm_job_identity.gid == 1000']}},
        ])
        result = self.run_play()
        self.assertEqual(result.returncode, 0, result.stdout)
        receipt = json.loads((self.receipts / 'slurm-head.json').read_text())
        self.assertEqual(receipt['facts'], SLURM_FACTS)

    def enable_checkpoints(self):
        self.receipts = self.root / 'checkpoints'
        play = yaml.safe_load(self.playbook.read_text())
        play[0]['vars'].update(core_checkpoint_enabled=True, core_checkpoint_dir=str(self.receipts))
        play[0].pop('post_tasks')
        self.write(self.playbook, play)
        for component, facts in [('slurm', SLURM_FACTS), ('lmod', LMOD_FACTS)]:
            path = self.components / component / 'tasks/head.yml'
            tasks = yaml.safe_load(path.read_text())
            tasks.append({'ansible.builtin.set_fact': facts})
            self.write(path, tasks)
            path = self.components / component / 'tasks/cpu_image.yml'
            tasks = yaml.safe_load(path.read_text())
            tasks.insert(0, {'ansible.builtin.assert': {'that': [
                key + ' == ' + repr(value) for key, value in facts.items()]}})
            self.write(path, tasks)
        for phase in self.catalog['core_deploy_phases']:
            path = self.components / phase['component'] / 'tasks' / (phase['entry'] + '.yml')
            tasks = yaml.safe_load(path.read_text())
            tasks.insert(0, {'ansible.builtin.fail': {'msg': 'INJECTED_FAILURE'},
                            'when': "test_failure | default('') == '" + phase['component'] + '/' + phase['entry'] + "'"})
            self.write(path, tasks)

    def test_resume_after_failure_skips_prefix_restores_facts_and_tracks_code_changes(self):
        self.enable_checkpoints()
        result = self.run_play('-e', 'test_failure=slurm/cpu_image')
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertTrue((self.receipts / 'slurm-head.json').exists())
        self.assertFalse((self.receipts / 'slurm-cpu_image.json').exists())
        result = self.run_play('-e', 'core_resume=true', '-e', 'test_failure=lmod/cpu_image')
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn('CHECKPOINT_SKIP::slurm/head', result.stdout)
        self.assertIn('PHASE_RAN::slurm/cpu_image', result.stdout)
        self.assertTrue((self.receipts / 'lmod-head.json').exists(), result.stdout)
        result = self.run_play('-e', 'core_resume=true')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('CHECKPOINT_SKIP::lmod/head', result.stdout)
        self.assertIn('PHASE_RAN::lmod/cpu_image', result.stdout)
        result = self.run_play('-e', 'core_resume=true')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertNotIn('PHASE_RAN::', result.stdout)
        self.assertIn('TEST_HANDOFF_EXECUTED', result.stdout)
        path = self.components / 'spack/tasks/head.yml'
        path.write_text(path.read_text() + '\n# installer changed\n')
        result = self.run_play('-e', 'core_resume=true')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('CHECKPOINT_SKIP::slurm/cpu_image', result.stdout)
        self.assertIn('PHASE_RAN::spack/head', result.stdout)
        self.assertIn('PHASE_RAN::warewulf/publish', result.stdout)

    def test_failed_handler_keeps_exclusive_lock_and_never_writes_success_receipt(self):
        self.enable_checkpoints()
        self.write(self.components / 'warewulf/handlers/main.yml', [
            {'name': 'Record Warewulf handler', 'ansible.builtin.fail': {'msg': 'HANDLER_FAILED'}}])
        result = self.run_play()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn('HANDLER_FAILED', result.stdout)
        self.assertEqual(list(self.receipts.glob('*.json')), [])
        # Ansible 2.14 treats fatal handlers outside the calling block's always
        # scope. Preserve exclusion rather than automatically expiring ownership.
        self.assertTrue((self.root / 'deploy-lock').exists(), result.stdout)
        retry = self.run_play('-e', 'core_resume=true')
        self.assertNotEqual(retry.returncode, 0, retry.stdout)
        self.assertIn('Deployment lock already exists', retry.stdout)

    def test_effective_inputs_resolve_real_defaults_and_nested_overrides(self):
        self.enable_checkpoints()
        # Use real defaults with recording roles, never real installers. A normal
        # exit must run block/always so the deployment lock is released.
        for component in ('warewulf', 'slurm', 'spack'):
            shutil.copytree(orchestration.ANSIBLE / 'components' / component / 'defaults',
                            self.components / component / 'defaults')
        self.write(self.role / 'tasks/phase.yml', [
            {'ansible.builtin.debug': {'var': 'core_checkpoint_plan'},
             'when': "core_phase.component == 'warewulf' and core_phase.entry == 'head'"}])
        play = yaml.safe_load(self.playbook.read_text())
        play[0]['vars'].update(core_components_dir=str(self.components),
                              warewulf_release_dir=str(self.root / 'releases'),
                              slurm_verify_user='jay', spack_packages='{{ test_packages }}',
                              test_packages=['hdf5'])
        self.write(self.playbook, play)
        first = self.run_play()
        self.assertEqual(first.returncode, 0, first.stdout)
        second = self.run_play('-e', '{"test_packages":["zlib"]}')
        self.assertEqual(second.returncode, 0, second.stdout)
        before = re.findall(r'"fingerprint": "([a-f0-9]+)"', first.stdout)
        after = re.findall(r'"fingerprint": "([a-f0-9]+)"', second.stdout)
        self.assertEqual(len(before), 9)
        self.assertTrue(all(a != b for a, b in zip(before, after)))
        self.assertNotIn('PHASE_RAN::', first.stdout + second.stdout)


class FingerprintTests(unittest.TestCase):
    def test_declared_overrides_and_component_source_invalidate_correct_suffix(self):
        source = orchestration.CORE / 'roles/hpc_core/action_plugins/hpc_core_fingerprint.py'
        spec = importlib.util.spec_from_file_location('checkpoint_filters', source)
        filters = importlib.util.module_from_spec(spec)
        with tempfile.TemporaryDirectory() as temporary:
            with patch.dict(os.environ, ANSIBLE_LOCAL_TEMP=temporary):
                spec.loader.exec_module(filters)
            root = Path(temporary)
            for component in ('warewulf', 'spack'):
                (root / component / 'tasks').mkdir(parents=True)
                (root / component / 'tasks/head.yml').write_text('[]')
                (root / component / 'defaults').mkdir()
                (root / component / 'defaults/main.yml').write_text(component + '_version: default\n')
            phases = [{'component': 'warewulf', 'entry': 'head'}, {'component': 'spack', 'entry': 'head'},
                      {'component': 'warewulf', 'entry': 'publish'}]
            def plan(**variables):
                return filters.checkpoint_plan(phases, str(root / 'core'), str(root), variables, {}, {})
            before = plan(spack_version='v1')
            # Adding a role without defaults (Lmod) still changes earlier behavior,
            # e.g. whether Spack must generate modules.
            extended = phases + [{'component': 'lmod', 'entry': 'head'}]
            changed_selection = filters.checkpoint_plan(
                extended, str(root / 'core'), str(root), {'spack_version': 'v1'}, {}, {})
            self.assertNotEqual(before[0], changed_selection[0])
            self.assertEqual(before, plan(spack_version='v1', core_resume=True, spack_runtime_result='ignored'))
            changed = plan(spack_version='v2')
            self.assertTrue(all(a != b for a, b in zip(before, changed)))
            (root / 'spack/tasks/head.yml').write_text('[]\n# new code')
            changed = plan(spack_version='v1')
            self.assertEqual(before[0], changed[0])
            self.assertNotEqual(before[1:], changed[1:])
