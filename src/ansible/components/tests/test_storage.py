"""Storage admission and user mapping, without disks, mounts or account changes."""
import grp
import contextlib
import io
import importlib.util
import json
import os
from pathlib import Path
import pwd
import subprocess
import tempfile
import unittest
from unittest.mock import patch
import yaml

from test_components import fixture, render

SOURCE = Path(__file__).resolve().parents[1] / 'storage/files/context.py'
spec = importlib.util.spec_from_file_location('storage_context', SOURCE)
storage = importlib.util.module_from_spec(spec)
spec.loader.exec_module(storage)


class StorageTests(unittest.TestCase):
    def test_actual_yaml_findmnt_commands_accept_comma_separated_columns(self):
        ansible = SOURCE.parents[3]
        defaults = yaml.safe_load((ansible / 'core/roles/hpc_core/defaults/main.yml').read_text())
        probe = defaults['core_checkpoint_probes']['storage-head']['commands'][0]
        tasks = yaml.safe_load((SOURCE.parents[1] / 'tasks/verify.yml').read_text())
        verify = next(t['ansible.builtin.command']['argv'] for t in tasks
                      if t.get('ansible.builtin.command', {}).get('argv', [''])[0] == 'findmnt')
        for argv in (probe, verify):
            with self.subTest(argv=argv):
                # Use the always-mounted root for a read-only test requiring no NFS or sudo.
                command = ['/' if arg == '/shared' else arg for arg in argv]
                result = subprocess.run(command, capture_output=True, text=True)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertTrue(result.stdout.strip())
                if '--json' in argv:
                    mount = json.loads(result.stdout)['filesystems'][0]
                    self.assertTrue({'source', 'fstype', 'options'} <= set(mount))

    def test_preflight_allows_new_loop_but_verification_requires_mount(self):
        settings = dict(backend='loop', size_gib=5, reserve=6 * 1024**3,
                        uuid='', minimum=1024**3, users=['alice'], projects=[])
        with patch.object(storage.sys, 'argv', ['context.py', json.dumps(settings)]), \
             patch.object(storage.os.path, 'ismount', return_value=False), \
             patch.object(storage.os.path, 'exists', return_value=False), \
             patch.object(storage.os.path, 'lexists', return_value=False), \
             patch.object(storage, 'inspect_loop', return_value=None), \
             patch.object(storage, 'identities', return_value={'users': [], 'projects': []}), \
             patch.object(storage, 'create_backing', side_effect=AssertionError('read only')):
            result = io.StringIO()
            with contextlib.redirect_stdout(result):
                storage.main()
            self.assertEqual(json.loads(result.getvalue())['fstype'], 'ext4')
            settings['require_mounted'] = True
            with patch.object(storage.sys, 'argv', ['context.py', json.dumps(settings)]), self.assertRaisesRegex(ValueError, 'must be mounted'):
                storage.main()

    def test_capacity_reserves_space_only_for_new_file(self):
        storage.check_capacity(11, 5, 6, False)
        storage.check_capacity(6, 5, 6, True)
        with self.assertRaises(ValueError):
            storage.check_capacity(10, 5, 6, False)
        with self.assertRaises(ValueError):
            storage.check_capacity(5, 5, 6, True)

    def test_real_file_creation_is_preallocated_and_never_reformats_on_retry(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'shared.img'
            size = 32 * 1024**2
            self.assertTrue(storage.create_backing(path, size, 0))
            first = storage.filesystem_info(path)
            self.assertEqual(first['TYPE'], 'ext4')
            self.assertGreaterEqual(path.stat().st_blocks * 512, size)
            with patch.object(storage, 'format_new_file', side_effect=AssertionError('must not reformat')):
                self.assertFalse(storage.create_backing(path, size, 0))
            self.assertEqual(storage.filesystem_info(path)['UUID'], first['UUID'])
            with self.assertRaisesRegex(ValueError, 'different size'):
                storage.create_backing(path, size * 2, 0)

    def test_failed_format_cleans_only_the_new_temporary_file(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'shared.img'
            with patch.object(storage, 'format_new_file', side_effect=subprocess.CalledProcessError(1, 'mkfs.ext4')):
                with self.assertRaises(subprocess.CalledProcessError):
                    storage.create_backing(path, 1024**2, 0)
            self.assertFalse(path.exists())
            self.assertEqual(list(Path(folder).iterdir()), [])

    def test_existing_unformatted_symlink_and_sparse_files_are_never_formatted(self):
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / 'shared.img'
            size = 1024**2
            with path.open('wb') as stream:
                os.fchmod(stream.fileno(), 0o600)
                os.posix_fallocate(stream.fileno(), 0, size)
            with patch.object(storage, 'format_new_file', side_effect=AssertionError('must not format')):
                with self.assertRaises(subprocess.CalledProcessError):
                    storage.create_backing(path, size, 0)
            path.unlink()
            with path.open('wb') as stream:
                os.fchmod(stream.fileno(), 0o600)
                stream.truncate(size)
            with self.assertRaisesRegex(ValueError, 'sparse'):
                storage.create_backing(path, size, 0)
            path.unlink()
            path.symlink_to('/etc/passwd')
            with self.assertRaisesRegex(ValueError, 'redirected'):
                storage.create_backing(path, size, 0)

    def test_mounted_loop_must_reference_the_right_whole_file(self):
        backing = Path('/var/lib/hpc-storage/shared.img')
        device = {'name': '/dev/loop3', 'back-file': str(backing), 'offset': 0, 'sizelimit': 0, 'ro': False}
        storage.validate_loop_source({'source': '/dev/loop3'}, backing, [device])
        for change in ({'back-file': '/tmp/other.img'}, {'offset': 512}, {'sizelimit': 1024}, {'ro': True}):
            with self.assertRaises(ValueError):
                storage.validate_loop_source({'source': '/dev/loop3'}, backing, [dict(device, **change)])

    def test_rejects_wrong_disk_root_filesystem_readonly_and_insufficient_space(self):
        mount = dict(target='/shared', fstype='xfs', uuid='data-uuid', options='rw,relatime', fsroot='/')
        storage.validate_mount(mount, 1, 2, 'data-uuid', 100, 50)
        for candidate, root_device, uuid, free in [
            (mount, 2, 'data-uuid', 100), (mount, 1, '', 100),
            (mount, 1, 'wrong', 100), (mount, 1, 'data-uuid', 49),
            (dict(mount, options='ro'), 1, 'data-uuid', 100),
            (dict(mount, fstype='tmpfs'), 1, 'data-uuid', 100),
            (dict(mount, fsroot='/subdirectory'), 1, 'data-uuid', 100),
            (dict(mount, target='/'), 1, 'data-uuid', 100)]:
            with self.subTest(candidate=candidate, uuid=uuid), self.assertRaises(ValueError):
                storage.validate_mount(candidate, root_device, 2, uuid, free, 50)

    def test_existing_head_ids_and_project_membership_are_required(self):
        account = pwd.struct_passwd(('alice', 'x', 1200, 1200, '', '/home/alice', '/bin/bash'))
        primary = grp.struct_group(('alice', 'x', 1200, []))
        project = grp.struct_group(('research', 'x', 1300, ['alice']))
        projects = [dict(name='work', group='research', members=['alice'])]
        with patch.object(storage.pwd, 'getpwnam', return_value=account), \
             patch.object(storage.grp, 'getgrgid', return_value=primary), \
             patch.object(storage.grp, 'getgrnam', return_value=project), \
             patch.object(storage.os, 'getgrouplist', return_value=[1200, 1300]):
            result = storage.identities(['alice'], projects)
            self.assertEqual(result['users'][0]['uid'], 1200)
            self.assertEqual(result['projects'][0]['gid'], 1300)
            with patch.object(storage.os, 'getgrouplist', return_value=[1200]), self.assertRaises(ValueError):
                storage.identities(['alice'], projects)
            with self.assertRaises(ValueError):
                storage.identities(['alice'], [dict(name='../escape', group='research', members=['alice'])])
            with self.assertRaises(ValueError):
                storage.identities(['alice', 'alice'], [])
            with patch.object(storage.pwd, 'getpwnam', side_effect=KeyError('missing')), self.assertRaises(KeyError):
                storage.identities(['missing'], [])

    def test_required_mount_has_no_boot_time_local_storage_fallback(self):
        script = render('storage', 'cpu-image.sh.j2')
        self.assertIn('Options=rw,hard,_netdev,nosuid,nodev', script)
        self.assertIn('BindsTo=shared.mount', script)
        self.assertIn('RequiresMountsFor=/shared', script)
        self.assertIn('ensure_dir /shared 0555 root root', script)
        self.assertNotIn('nofail', script)
        self.assertNotIn('mount /shared', script)
        self.assertNotIn('systemctl start', script)

    def test_storage_opens_private_nfs_without_selecting_spack(self):
        values = fixture()
        values['core_components'] = ['warewulf', 'storage']
        self.assertIn('<service name="nfs"/>', render('warewulf', 'cluster-zone.xml.j2', values))

    def test_project_identity_checks_precede_package_or_account_changes(self):
        values = fixture()
        values['storage_context']['projects'] = [dict(name='science', group='research', gid=1300, members=['testuser'])]
        script = render('storage', 'cpu-image.sh.j2', values)
        self.assertLess(script.index('getent group research'), script.index('install_packages'))
        self.assertIn('groupadd --gid 1300 research', script)
        self.assertIn('usermod -a -G research testuser', script)
        syntax = subprocess.run(['bash', '-n'], input=script, text=True, capture_output=True)
        self.assertEqual(syntax.returncode, 0, syntax.stderr)
        self.assertEqual(syntax.stderr, '')
