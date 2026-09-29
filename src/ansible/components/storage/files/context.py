"""Read-only admission, plus explicit creation of a new private loop filesystem."""
import grp
import json
import os
import pwd
import re
import stat
import subprocess
import sys
import tempfile
from pathlib import Path

BACKING = Path('/var/lib/hpc-storage/shared.img')


def free_bytes(path):
    space = os.statvfs(path)
    return space.f_bavail * space.f_frsize


def filesystem_info(path):
    output = subprocess.check_output(['blkid', '-p', '-o', 'export', str(path)], text=True)
    return dict(line.split('=', 1) for line in output.splitlines() if '=' in line)


def validate_backing(path, size):
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_nlink != 1 or info.st_uid != os.geteuid() or info.st_mode & 0o077:
        raise ValueError('Backing file must be a private, owned regular file with no hardlinks')
    if info.st_size != size:
        raise ValueError('Existing backing file has a different size; automatic resizing or reformatting is forbidden')
    if info.st_blocks * 512 < size:
        raise ValueError('Backing file is sparse or was trimmed; restore its allocation before retrying')
    fs = filesystem_info(path)
    if fs.get('TYPE') != 'ext4' or not fs.get('UUID'):
        raise ValueError('Existing backing file is not valid ext4; it will not be reformatted')
    return fs


def check_capacity(available, size, reserve, exists):
    required = reserve + (0 if exists else size)
    if available < required:
        raise ValueError('Root filesystem needs %d free bytes (%d reserved for head/image builds)' % (required, reserve))


def inspect_loop(path, size, reserve):
    if os.path.realpath(path) != str(path):
        raise ValueError('Refusing redirected backing file path')
    ancestor = path.parent
    while not ancestor.exists():
        ancestor = ancestor.parent
    if ancestor.stat().st_dev != os.stat('/').st_dev:
        raise ValueError('Loop backing file must reside on the head root filesystem')
    if path.parent.exists():
        directory = path.parent.stat()
        if not stat.S_ISDIR(directory.st_mode) or directory.st_uid != os.geteuid() or directory.st_mode & 0o077:
            raise ValueError('Backing directory must be private and owned by the effective user')
        if list(path.parent.glob('.shared-*.building')):
            raise ValueError('Interrupted creation file in ' + str(path.parent) + '; inspect it after stopping all deployments before removing it')
    exists = os.path.lexists(path)
    check_capacity(free_bytes(ancestor), size, reserve, exists)
    return validate_backing(path, size) if exists else None


def format_new_file(path):
    # nodiscard is essential: mkfs must not punch holes in the reservation.
    subprocess.run(['mkfs.ext4', '-F', '-q', '-m', '0', '-E',
                    'nodiscard,lazy_itable_init=0,lazy_journal_init=0', str(path)],
                   check=True, stdout=subprocess.DEVNULL)


def create_backing(path, size, reserve):
    """Publish only a fully formatted new file; never format an existing path."""
    if inspect_loop(path, size, reserve) is not None:
        return False
    path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(prefix='.shared-', suffix='.building', dir=path.parent)
    try:
        os.posix_fallocate(fd, 0, size)
        os.fsync(fd)
        format_new_file(temporary)
        os.fsync(fd)
        validate_backing(Path(temporary), size)
        # link() is an exclusive publication: a concurrent existing file wins.
        os.link(temporary, path)
    finally:
        os.close(fd)
        os.unlink(temporary)
    directory_fd = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(directory_fd)
    finally:
        os.close(directory_fd)
    return True


def validate_loop_source(mount, backing, devices):
    for device in devices:
        if device.get('name') == mount.get('source'):
            if (os.path.realpath(device.get('back-file', '')) == str(backing)
                    and int(device.get('offset', -1)) == 0
                    and int(device.get('sizelimit', -1)) == 0
                    and not device.get('ro')):
                return
    raise ValueError('/shared is not mounted from the configured whole writable backing file')


def validate_mount(mount, root_device, shared_device, expected_uuid, free, minimum):
    if not expected_uuid or mount.get('uuid') != expected_uuid:
        raise ValueError('Set storage_filesystem_uuid to the UUID of the filesystem mounted at /shared')
    if mount.get('target') != '/shared' or mount.get('fstype') not in ('xfs', 'ext4') or mount.get('fsroot') != '/':
        raise ValueError('/shared must be a dedicated mounted XFS or ext4 filesystem')
    if root_device == shared_device or 'rw' not in mount.get('options', '').split(','):
        raise ValueError('/shared must be writable and separate from the head root filesystem')
    if free < minimum:
        raise ValueError('Insufficient free space on /shared')


def identities(users, projects):
    valid = lambda name: isinstance(name, str) and re.fullmatch(r'[a-z_][a-z0-9_-]*', name)
    if not isinstance(users, list) or not users or not all(valid(n) for n in users) or len(set(users)) != len(users):
        raise ValueError('storage_users must contain unique existing head usernames')
    accounts = []
    for name in users:
        account = pwd.getpwnam(name)
        group = grp.getgrgid(account.pw_gid)
        if account.pw_uid < 1000 or account.pw_gid < 1000 or not valid(group.gr_name):
            raise ValueError('Storage users require normal non-root UID/GIDs and safe group names')
        accounts.append(dict(name=name, uid=account.pw_uid, gid=account.pw_gid, group=group.gr_name))
    if len({a['uid'] for a in accounts}) != len(accounts):
        raise ValueError('Storage users must have distinct UIDs')
    if not isinstance(projects, list):
        raise ValueError('storage_projects must be a list')
    result = []
    names = set()
    for project in projects:
        if not isinstance(project, dict) or not valid(project.get('name')) or not valid(project.get('group')):
            raise ValueError('Projects require safe name and group fields')
        members = project.get('members')
        if not isinstance(members, list) or not members or not all(n in users for n in members):
            raise ValueError('Project members must be declared storage_users')
        group = grp.getgrnam(project['group'])
        if group.gr_gid < 1000 or project['name'] in names:
            raise ValueError('Projects require unique names and non-system groups')
        for name in members:
            if group.gr_gid not in os.getgrouplist(name, pwd.getpwnam(name).pw_gid):
                raise ValueError(name + ' must already belong to project group ' + group.gr_name + ' on the head')
        names.add(project['name'])
        result.append(dict(name=project['name'], group=group.gr_name, gid=group.gr_gid, members=members))
    return dict(users=accounts, projects=result)


def main():
    settings = json.loads(sys.argv[1])
    backend = settings.get('backend', 'existing')
    if backend not in ('loop', 'existing'):
        raise ValueError('storage_backend must be loop or existing')
    if os.path.realpath('/shared') != '/shared':
        raise ValueError('Refusing redirected /shared path')
    mounted = os.path.ismount('/shared')
    minimum = int(settings['minimum'])
    expected_uuid = settings.get('uuid', '')
    if backend == 'loop':
        size_gib = settings['size_gib']
        if type(size_gib) is not int or size_gib < 1 or minimum < 0:
            raise ValueError('storage_size_gib must be a positive integer')
        size = size_gib * 1024**3
        reserve = int(settings['reserve'])
        if size <= minimum + 128 * 1024**2 or reserve < 0:
            raise ValueError('Backing file needs room for filesystem metadata and the free-space threshold')
        fs = inspect_loop(BACKING, size, reserve)
        if fs:
            if expected_uuid and expected_uuid != fs['UUID']:
                raise ValueError('Configured UUID differs from existing loop filesystem')
            expected_uuid = fs['UUID']
        elif expected_uuid:
            raise ValueError('Leave storage_filesystem_uuid empty when creating a new loop filesystem')
        if mounted and not fs:
            raise ValueError('/shared is already mounted from another filesystem')
        if not mounted and os.path.exists('/shared') and (not os.path.isdir('/shared') or os.listdir('/shared')):
            raise ValueError('Refusing to hide existing files at unmounted /shared')
    elif not mounted:
        raise ValueError('Mount a dedicated data filesystem at /shared first for storage_backend=existing')
    if settings.get('require_mounted') and not mounted:
        raise ValueError('/shared must be mounted before image preparation or verification')
    mount = None
    if mounted:
        mount = json.loads(subprocess.check_output(
            ['findmnt', '--json', '--mountpoint', '/shared', '--output', 'SOURCE,TARGET,FSTYPE,UUID,OPTIONS,FSROOT'], text=True))['filesystems'][0]
        validate_mount(mount, os.stat('/').st_dev, os.stat('/shared').st_dev,
                       expected_uuid, free_bytes('/shared'), minimum)
        if backend == 'loop':
            devices = json.loads(subprocess.check_output(
                ['losetup', '--json', '--list', '--output', 'NAME,BACK-FILE,OFFSET,SIZELIMIT,RO'], text=True))['loopdevices']
            validate_loop_source(mount, BACKING, devices)
    result = identities(settings['users'], settings['projects'])
    directories = ['/shared/users', '/shared/projects', '/shared/scratch']
    directories += ['/shared/' + area + '/' + a['name'] for area in ('users', 'scratch') for a in result['users']]
    directories += ['/shared/projects/' + p['name'] for p in result['projects']]
    for directory in directories:
        if os.path.realpath(directory) != directory or (os.path.lexists(directory) and not stat.S_ISDIR(os.lstat(directory).st_mode)):
            raise ValueError('Shared directories must not be redirected or special files: ' + directory)
    result['fstype'] = mount['fstype'] if mount else 'ext4'
    if len(sys.argv) > 2 and sys.argv[2] == '--create':
        if backend != 'loop':
            raise ValueError('Only the loop backend can create a new filesystem file')
        print(json.dumps({'changed': create_backing(BACKING, size, reserve)}))
        return
    print(json.dumps(result))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, KeyError, TypeError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
