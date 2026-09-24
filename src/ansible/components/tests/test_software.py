"""Exercise shell integration in temporary trees; no packages are installed."""
import os
import pty
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import unittest

import yaml
from jinja2 import Environment

from test_components import fixture, render


class SoftwareShellTests(unittest.TestCase):
    def test_spack_image_fstab_missing_existing_and_repeated_configuration(self):
        # Execute the rendered fstab logic against a temporary file. Stub only
        # the shared writer so no root permissions or real image are needed.
        for initial in (None, '', '# existing mounts\nUUID=test /data xfs defaults 0 2\n'):
            with self.subTest(initial=initial), tempfile.TemporaryDirectory() as folder:
                target = Path(folder) / 'fstab'
                if initial is not None:
                    target.write_text(initial)

                def configure(address):
                    values = fixture()
                    values['core_cluster']['head']['address'] = address
                    script = render('spack', 'cpu-image.sh.j2', values)
                    start = script.index('fstab="$(mktemp)"')
                    end = script.index('put_file /etc/profile.d/')
                    script = script[start:end].replace('/etc/fstab', shlex.quote(str(target)))
                    result = subprocess.run(['bash', '-c',
                        'set -euo pipefail\nput_file() { cat > "$1"; }\n' + script],
                        capture_output=True, text=True)
                    self.assertEqual(result.returncode, 0, result.stderr)
                    return target.read_text()

                first = configure('10.0.0.1')
                self.assertTrue(first.startswith(initial or ''))
                self.assertIn('10.0.0.1:/opt/spack /opt/spack nfs4 ro,nofail,', first)
                self.assertEqual(configure('10.0.0.1'), first)
                updated = configure('10.0.0.2')
                self.assertTrue(updated.startswith(initial or ''))
                self.assertEqual(updated.count('# BEGIN HPC SPACK'), 1)
                self.assertEqual(updated.count('# END HPC SPACK'), 1)
                self.assertNotIn('10.0.0.1:', updated)
                self.assertIn('10.0.0.2:/opt/spack', updated)

    def test_lockfile_validation_rejects_empty_and_corrupt_dependency_plans(self):
        path = Path(__file__).resolve().parents[1] / 'spack/tasks/validate_lockfile.yml'
        validator = yaml.safe_load(path.read_text())[0]['ansible.builtin.command']['argv'][2]
        with tempfile.TemporaryDirectory() as folder:
            lock = Path(folder) / 'spack.lock'
            for content, valid in [('', False), ('{', False), ('{}', False),
                                   ('{"roots": [], "concrete_specs": {}}', True)]:
                with self.subTest(content=content):
                    lock.write_text(content)
                    result = subprocess.run([sys.executable, '-c', validator, str(lock)],
                                            capture_output=True, text=True)
                    self.assertEqual(result.returncode == 0, valid, result.stderr)
                    self.assertEqual(lock.read_text(), content)
                    if not valid:
                        self.assertIn(str(lock), result.stderr)
                        self.assertIn('installation database must be retained', result.stderr)

    def test_spack_install_with_noncontrolling_pty_and_build_failure(self):
        tasks = yaml.safe_load((Path(__file__).resolve().parents[1] /
                                'spack/tasks/head.yml').read_text())
        task = next(t for t in tasks if t['name'] == 'Install missing software in the environment')
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'bin').mkdir()
            stub = root / 'bin/spack'
            stub.write_text('#!' + sys.executable + '\n' + '''
import os, pathlib, sys
root = pathlib.Path(__file__).resolve().parents[1]
# Reproduce Spack's failing terminal query, with no real package installation.
# Bash can acquire the PTY at startup; detach this child like a logger daemon.
os.setsid()
if sys.stdin.isatty():
    os.tcgetpgrp(sys.stdin.fileno())
if 'install' in sys.argv:
    if (root / 'fail').exists():
        sys.exit(7)
    (root / 'installed').touch()
elif (root / 'installed').exists():
    print('installed-hash')
''')
            stub.chmod(0o755)
            env = Environment()
            env.filters['quote'] = shlex.quote
            script = env.from_string(task['ansible.builtin.shell']).render(
                spack_install_dir=folder, spack_environment_dir=folder + '/environment')
            master, slave = pty.openpty()
            try:
                def run(body):
                    return subprocess.run(['bash', '-c', body], stdin=slave,
                                          stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                          start_new_session=True, text=True, timeout=10)
                broken = run(script.replace('exec </dev/null', ':'))
                self.assertNotEqual(broken.returncode, 0)
                self.assertIn('Inappropriate ioctl for device', broken.stderr)
                fixed = run(script)
                self.assertEqual(fixed.returncode, 0, fixed.stderr)
                self.assertIn('HPC_SPACK_CHANGED', fixed.stdout)
                repeated = run(script)
                self.assertEqual(repeated.returncode, 0, repeated.stderr)
                self.assertNotIn('HPC_SPACK_CHANGED', repeated.stdout)
                (root / 'fail').touch()
                failed = run(script)
                self.assertEqual(failed.returncode, 7)
                self.assertNotIn('HPC_SPACK_CHANGED', failed.stdout)
            finally:
                os.close(slave)
                os.close(master)

    def bash(self, script):
        return subprocess.run(['bash', '--noprofile', '--norc', '-s'], input=script,
                              env={'PATH': '/usr/bin:/bin'}, text=True,
                              capture_output=True, timeout=10)

    def test_spack_initializes_only_when_invoked_and_preserves_arguments(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            init = root / 'share/spack/setup-env.sh'
            init.parent.mkdir(parents=True)
            init.write_text("echo INITIALIZED\nspack() { printf '<%s>\\n' \"$@\"; }\n")
            values = fixture()
            values['spack_install_dir'] = folder
            profile = render('spack', 'spack.sh.j2', values)
            result = self.bash(profile + '\necho BEFORE_CALL\nspack find "hdf5 +mpi"\nspack --version\n')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(result.stdout.startswith('BEFORE_CALL\nINITIALIZED\n'), result.stdout)
            self.assertEqual(result.stdout.count('INITIALIZED'), 1)
            self.assertIn('<hdf5 +mpi>', result.stdout)

    def test_missing_spack_tree_does_not_break_profile_initialization(self):
        values = fixture()
        with tempfile.TemporaryDirectory() as folder:
            values['spack_install_dir'] = folder
            result = self.bash(render('spack', 'spack.sh.j2', values) +
                               '\necho PROFILE_OK\nspack --version\n')
            self.assertIn('PROFILE_OK', result.stdout)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Spack is unavailable', result.stderr)

    def test_lmod_profile_preserves_paths_and_does_not_duplicate_its_entry(self):
        with tempfile.TemporaryDirectory() as folder:
            init = Path(folder) / 'init.sh'
            init.write_text('export LMOD_CMD=/fake/lmod\nmodule() { :; }\n')
            profile = render('lmod', 'lmod.sh.j2').replace(
                '/usr/share/lmod/lmod/init/bash', str(init))
            result = self.bash('export MODULEPATH=/existing/modules\n' + profile + profile +
                               '\nprintf "%s\\n" "$MODULEPATH"\n')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), '/opt/spack/modules/lmod/Core:/existing/modules')

    def test_module_smoke_test_rejects_wrong_executable_even_if_it_runs(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            prefix = root / 'software'
            (prefix / 'bin').mkdir(parents=True)
            expected = prefix / 'bin/h5dump'
            expected.write_text('#!/bin/sh\necho HDF5_TEST\n')
            expected.chmod(0o755)
            other = root / 'other'
            other.mkdir()
            impostor = other / 'h5dump'
            impostor.write_text(expected.read_text())
            impostor.chmod(0o755)
            profile = root / 'profile.sh'
            values = fixture()
            values['hpc_spack_module_test']['prefix'] = str(prefix)
            script = render('lmod', 'verify.sh.j2', values).replace(
                '/etc/profile.d/z10-hpc-lmod.sh', str(profile))
            for binary_dir, success in [(prefix / 'bin', True), (other, False)]:
                with self.subTest(binary_dir=binary_dir):
                    # Stub only the runtime; execute the actual acceptance script.
                    profile.write_text('export LMOD_CMD=/fake/lmod\nmodule() { export PATH=' +
                                       shlex.quote(str(binary_dir)) + ':"$PATH"; }\n')
                    result = self.bash(script)
                    self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
                    self.assertEqual('HDF5_TEST' in result.stdout, success)


if __name__ == '__main__':
    unittest.main()
