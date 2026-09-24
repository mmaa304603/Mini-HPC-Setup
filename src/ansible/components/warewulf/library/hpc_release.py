#!/usr/bin/python
"""Private publication bundles and an atomic release selector.

Call activate/rollback ONLY with provisioning services stopped. Interrupted
activation is detected by pending.json and must be rolled back before retrying.
No package, rootfs or controller-service rollback is implied.
"""
import hashlib
import json
import os
from pathlib import Path
import shutil
import tempfile
import uuid
from ansible.module_utils.basic import AnsibleModule

LAYOUT = {'nodes': ('/etc/warewulf/nodes.conf', 'etc/warewulf/nodes.conf'),
          'dhcp': ('/etc/dhcp/dhcpd.conf', 'etc/dhcp/dhcpd.conf'),
          'provision': ('/var/lib/warewulf/provision', 'provision'),
          'metadata': ('/var/lib/hpc-setup/images', 'metadata')}


def sync_directory(base):
    fd = os.open(base, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def select(base, target, name='current'):
    temporary = base / ('.selector-' + uuid.uuid4().hex)
    temporary.symlink_to(target)
    os.replace(temporary, base / name)
    sync_directory(base)


def write_json(path, data):
    fd, temporary = tempfile.mkstemp(dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as stream:
            json.dump(data, stream, sort_keys=True)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        sync_directory(path.parent)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def file_digest(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(block)
    return digest.hexdigest()


def install_dhcp_config(source, destination):
    """Atomically install DHCP configuration outside the private release tree.

    dhcpd drops privileges and cannot traverse the mode-0700 release directory.
    A regular file also receives the normal /etc/dhcp SELinux type when created
    in that directory; the playbook restores the policy label before startup.
    """
    if not source.is_file():
        raise ValueError('Missing staged DHCP configuration: ' + str(source))
    destination.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.hpc-dhcp-', dir=destination.parent)
    try:
        with os.fdopen(fd, 'wb') as stream, source.open('rb') as staged:
            shutil.copyfileobj(staged, stream)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(temporary, 0o644)
        os.replace(temporary, destination)
        sync_directory(destination.parent)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def selected_release(base):
    selector = base / 'current'
    if not selector.is_symlink():
        return None
    selected = selector.resolve()
    if selected.parent != base or not selected.is_dir():
        raise ValueError('Invalid current release selector')
    return selected


def retain_only(base, release):
    """Keep one selected release after rollback is no longer required."""
    if release.parent != base or not release.is_dir():
        raise ValueError('Cannot retain an invalid release')
    # Keep rollback valid while stale directories are removed. After a
    # successful commit, rollback deliberately resolves to the active release.
    select(base, release, 'previous')
    for candidate in base.iterdir():
        if not candidate.name.startswith('release-') or candidate == release:
            continue
        if candidate.is_symlink() or not candidate.is_dir():
            raise ValueError('Unexpected release entry: ' + str(candidate))
        shutil.rmtree(candidate)
    sync_directory(base)


def manifest(directory):
    entries = {}
    for folder in ('provision', 'etc/warewulf', 'etc/dhcp', 'metadata', 'chroots'):
        for path in sorted((directory / folder).rglob('*')):
            if path.is_symlink():
                # A link escaping the release could defeat integrity/rollback.
                # Absolute links inside a chroot refer to that image's root,
                # not the head's root. Hash their link text without following.
                if folder != 'chroots' and directory.resolve() not in path.resolve().parents:
                    raise ValueError('Release contains an external symlink: ' + str(path))
                entries[str(path.relative_to(directory))] = {'symlink': os.readlink(path)}
                continue
            if path.is_file():
                entries[str(path.relative_to(directory))] = file_digest(path)
    return entries


def execute(base, state, release='', layout=None, etc_source='/etc/warewulf'):
    layout = layout or LAYOUT
    base = Path(base)
    if not base.is_absolute() or str(base.resolve()) != str(base) or str(base) == '/':
        raise ValueError('Release directory must be canonical and absolute')
    if state == 'begin':
        base.mkdir(mode=0o700, parents=True, exist_ok=True)
    if base.stat().st_uid != os.geteuid() or base.stat().st_mode & 0o077:
        raise ValueError('Release directory must be private and owned by the effective user')
    pending = base / 'pending.json'
    if state == 'begin':
        if pending.exists():
            raise ValueError('Interrupted publication: rollback the pending release before deploying')
        active = selected_release(base)
        if active is not None:
            # Clean abandoned staging directories before allocating another
            # full image snapshot. The active release remains available.
            retain_only(base, active)
        directory = base / ('release-' + uuid.uuid4().hex)
        directory.mkdir(mode=0o700)
        shutil.copytree(etc_source, directory / 'etc/warewulf', symlinks=False)
        for source, relative in layout.values():
            destination = directory / relative
            if destination.exists():
                continue
            destination.parent.mkdir(parents=True, exist_ok=True)
            if Path(source).is_dir():
                shutil.copytree(source, destination, symlinks=False)
            elif Path(source).is_file():
                shutil.copy2(source, destination)
            elif relative in ('provision', 'metadata'):
                destination.mkdir()
            else:
                destination.touch(mode=0o600)
        return dict(changed=True, release=str(directory))
    if state == 'rollback':
        previous = Path(json.loads(pending.read_text())['previous']) if pending.exists() else (base / 'previous').resolve()
        if previous.parent != base or not previous.is_dir():
            raise ValueError('Invalid rollback release')
        # Repair stable pointers even if a process stopped midway through first migration.
        bind_layout(base, previous.name, layout)
        select(base, previous)
        (base / 'switching').unlink(missing_ok=True)
        if pending.exists():
            pending.unlink()
            sync_directory(base)
        return dict(changed=True, release=str(previous))
    directory = Path(release) if release else (base / 'current').resolve()
    if directory.parent != base or not directory.is_dir():
        raise ValueError('Release must be an existing direct child of the private release directory')
    if state == 'seal':
        entries = manifest(directory)
        if not entries:
            raise ValueError('Cannot seal an empty publication')
        write_json(directory / 'manifest.json', entries)
    elif state in ('verify', 'activate'):
        if json.loads((directory / 'manifest.json').read_text()) != manifest(directory):
            raise ValueError('Publication manifest does not match its files')
        if state == 'verify' and not release:
            for name, (source, relative) in layout.items():
                if name == 'dhcp':
                    if not Path(source).is_file() or file_digest(Path(source)) != file_digest(directory / relative):
                        raise ValueError('Live DHCP configuration changed: ' + source)
                elif not Path(source).is_symlink() or os.readlink(source) != str(base / 'current' / relative):
                    raise ValueError('Live publication pointer changed: ' + source)
        if state == 'activate':
            if pending.exists():
                raise ValueError('Another publication is pending')
            if not (base / 'current').is_symlink():
                # Snapshot the old live layout before first migration.
                previous = execute(str(base), 'begin', layout=layout, etc_source=etc_source)['release']
                execute(str(base), 'seal', release=previous, layout=layout, etc_source=etc_source)
                select(base, previous)
            previous = str((base / 'current').resolve())
            write_json(pending, dict(previous=previous, release=str(directory)))
            write_json(base / 'switching', {'release': str(directory)})
            select(base, previous, 'previous')
            bind_layout(base, directory.name, layout)
            select(base, directory)
            (base / 'switching').unlink()
            sync_directory(base)
    elif state == 'finish':
        if not pending.exists() or json.loads(pending.read_text())['release'] != str(directory):
            raise ValueError('Publication ownership mismatch')
        pending.unlink()
        retain_only(base, directory)
    return dict(changed=state != 'verify', release=str(directory))


def bind_layout(base, name, layout):
    for entry, (source, relative) in layout.items():
        path = Path(source)
        if entry == 'dhcp':
            install_dhcp_config(base / name / relative, path)
            continue
        expected = base / 'current' / relative
        if path.is_symlink() and os.readlink(path) == str(expected):
            continue
        if path.exists() or path.is_symlink():
            backup = str(path) + '.before-core-' + name
            if os.path.lexists(backup):
                raise ValueError('Refusing to overwrite a migration backup: ' + backup)
            os.rename(path, backup)
            # First migration must not leave locally readable legacy archives
            # containing Munge/SSH keys beside the protected release tree.
            if not Path(backup).is_symlink():
                os.chmod(backup, 0o700 if Path(backup).is_dir() else 0o600)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.symlink_to(expected)
        sync_directory(path.parent)


def main():
    module = AnsibleModule(argument_spec=dict(base=dict(type='path', required=True),
        state=dict(choices=['begin', 'seal', 'activate', 'verify', 'rollback', 'finish'], required=True),
        release=dict(type='path', default='')))
    try:
        module.exit_json(**execute(**module.params))
    except (OSError, ValueError, KeyError) as exc:
        module.fail_json(msg=str(exc))


if __name__ == '__main__':
    main()
