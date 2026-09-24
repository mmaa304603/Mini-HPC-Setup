"""Exercise locks, state drift and publication transactions in temporary trees."""
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

CORE = Path(__file__).resolve().parents[1]


def module(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


lock = module('lock_audit', CORE / 'roles/hpc_core/library/hpc_core_lock.py')
receipts = module('receipt_audit', CORE / 'roles/hpc_core/library/hpc_core_checkpoint.py')
release = module('release_audit', CORE.parent / 'components/warewulf/library/hpc_release.py')


class LockTests(unittest.TestCase):
    def test_second_owner_and_wrong_release_token_are_rejected(self):
        with tempfile.TemporaryDirectory() as root:
            directory = root + '/lock'
            owner = lock.execute(directory, 'acquire')
            with self.assertRaises(ValueError):
                lock.execute(directory, 'acquire')
            with self.assertRaises(ValueError):
                lock.execute(directory, 'release', 'wrong')
            self.assertTrue(Path(directory).exists())
            lock.execute(directory, 'release', owner['token'])
            self.assertFalse(Path(directory).exists())
            lock.execute(directory, 'acquire')


class DriftTests(unittest.TestCase):
    def test_changed_or_missing_artifacts_and_failed_probes_invalidate_suffix(self):
        for drift in ('changed', 'missing', 'service'):
            with self.subTest(drift=drift), tempfile.TemporaryDirectory() as root:
                artifact = Path(root) / 'config'
                artifact.write_text('installed')
                health = Path(root) / 'health'
                health.write_text('exit 0\n')
                args = dict(directory=root + '/receipts', state='prepare', resume=True,
                            phase='', facts={}, plan=[{'phase': 'warewulf-head', 'fingerprint': 'a'*64}],
                            probes={'warewulf-head': {'paths': [str(artifact)], 'commands': [['bash', str(health)]]}})
                receipts.execute(args)
                receipts.execute(dict(args, state='save', phase='warewulf-head'))
                self.assertEqual(receipts.execute(args)['skipped'], ['warewulf-head'])
                if drift == 'changed': artifact.write_text('drift')
                if drift == 'missing': artifact.unlink()
                if drift == 'service': health.write_text('exit 1\n')
                self.assertEqual(receipts.execute(args)['skipped'], [])
                self.assertFalse((Path(root) / 'receipts/warewulf-head.json').exists())


class ReleaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.base = self.root / 'releases'
        self.live = self.root / 'live'
        self.etc = self.live / 'etc/warewulf'
        self.etc.mkdir(parents=True)
        (self.etc / 'nodes.conf').write_text('old nodes')
        (self.etc / 'warewulf.conf').write_text('configuration')
        (self.live / 'etc/dhcp').mkdir()
        (self.live / 'etc/dhcp/dhcpd.conf').write_text('old dhcp')
        (self.live / 'provision').mkdir()
        (self.live / 'provision/image').write_text('old image')
        (self.live / 'metadata').mkdir()
        self.layout = {name: (str(self.live / relative), relative) for name, (_, relative) in release.LAYOUT.items()}

    def call(self, state, directory=''):
        return release.execute(str(self.base), state, directory, self.layout, str(self.etc))

    def staged(self):
        stage = Path(self.call('begin')['release'])
        (stage / 'provision/image').write_text('new image')
        (stage / 'etc/warewulf/nodes.conf').write_text('new nodes')
        (stage / 'etc/dhcp/dhcpd.conf').write_text('new dhcp')
        self.call('seal', str(stage))
        return stage

    def test_success_keeps_only_active_release(self):
        stage = self.staged()
        self.assertEqual((self.live / 'provision/image').read_text(), 'old image')
        self.call('activate', str(stage))
        self.assertEqual((self.live / 'provision/image').read_text(), 'new image')
        self.assertEqual((self.etc / 'nodes.conf').read_text(), 'new nodes')
        dhcp = self.live / 'etc/dhcp/dhcpd.conf'
        self.assertFalse(dhcp.is_symlink())
        self.assertEqual(dhcp.read_text(), 'new dhcp')
        self.call('verify')
        self.call('finish', str(stage))
        releases = [path for path in self.base.glob('release-*') if path.is_dir()]
        self.assertEqual(releases, [stage])
        self.assertEqual((self.base / 'previous').resolve(), stage)
        self.call('rollback')
        self.assertEqual((self.live / 'provision/image').read_text(), 'new image')
        self.assertEqual((self.etc / 'nodes.conf').read_text(), 'new nodes')
        self.assertFalse(dhcp.is_symlink())
        self.assertEqual(dhcp.read_text(), 'new dhcp')
        self.call('verify')

    def test_begin_removes_abandoned_staging_after_a_success(self):
        stage = self.staged()
        self.call('activate', str(stage))
        self.call('finish', str(stage))
        abandoned = self.base / 'release-abandoned'
        abandoned.mkdir()
        next_stage = Path(self.call('begin')['release'])
        self.assertFalse(abandoned.exists())
        self.assertTrue(stage.is_dir())
        self.assertTrue(next_stage.is_dir())

    def test_corrupt_staging_is_not_activated(self):
        stage = self.staged()
        (stage / 'provision/image').write_text('corruption')
        with self.assertRaises(ValueError): self.call('activate', str(stage))
        self.assertEqual((self.live / 'provision/image').read_text(), 'old image')

    def test_interrupted_migration_blocks_retry_and_can_restore_pointers(self):
        stage = self.staged()
        original = release.bind_layout
        def interrupt(base, name, layout):
            original(base, name, dict(list(layout.items())[:1]))
            raise OSError('simulated interruption')
        with patch.object(release, 'bind_layout', interrupt):
            with self.assertRaises(OSError): self.call('activate', str(stage))
        self.assertTrue((self.base / 'switching').exists())
        with self.assertRaises(ValueError): self.call('begin')
        self.call('rollback')
        self.assertFalse((self.base / 'switching').exists())
        self.assertEqual((self.etc / 'nodes.conf').read_text(), 'old nodes')
        self.assertEqual((self.live / 'provision/image').read_text(), 'old image')

    def test_overlay_drift_is_detected_after_activation(self):
        stage = self.staged()
        self.call('activate', str(stage))
        (stage / 'provision/image').write_text('drift')
        with self.assertRaises(ValueError): self.call('verify')

    def test_replaced_live_pointer_is_detected(self):
        stage = self.staged()
        self.call('activate', str(stage))
        (self.etc / 'nodes.conf').unlink()
        (self.etc / 'nodes.conf').write_text('unmanaged configuration')
        with self.assertRaises(ValueError): self.call('verify')

    def test_frozen_kernel_drift_is_detected_and_legacy_archives_are_private(self):
        stage = self.staged()
        kernel = stage / 'chroots/frozen/rootfs/boot/vmlinuz'
        kernel.parent.mkdir(parents=True)
        kernel.write_bytes(b'kernel')
        (kernel.parent / 'kernel-link').symlink_to('/boot/vmlinuz')
        self.call('seal', str(stage))
        self.call('activate', str(stage))
        backups = list(self.live.glob('provision.before-core-*'))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].stat().st_mode & 0o777, 0o700)
        kernel.write_bytes(b'drift')
        with self.assertRaises(ValueError): self.call('verify')
