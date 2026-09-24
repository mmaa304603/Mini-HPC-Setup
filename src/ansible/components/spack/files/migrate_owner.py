"""Migrate dedicated legacy Spack trees without following mutable path links."""
import os
import pwd
import stat
import sys


def migrate(roots, uid, gid):
    if uid == 0 or gid == 0:
        raise ValueError('Spack builder must not use root IDs')
    changed = False

    def walk(fd, device, visitor):
        info = os.fstat(fd)
        if info.st_dev != device:
            return
        if not (stat.S_ISDIR(info.st_mode) or stat.S_ISREG(info.st_mode)):
            raise ValueError('Unexpected special file in Spack ownership migration')
        visitor(fd, info)
        if stat.S_ISDIR(info.st_mode):
            for name in os.listdir(fd):
                expected = os.stat(name, dir_fd=fd, follow_symlinks=False)
                if stat.S_ISLNK(expected.st_mode) or expected.st_dev != device:
                    continue
                # Parent directory handles and O_NOFOLLOW prevent a replaced
                # directory/symlink from redirecting root ownership changes.
                child_fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK, dir_fd=fd)
                try:
                    actual = os.fstat(child_fd)
                    if (actual.st_dev, actual.st_ino, stat.S_IFMT(actual.st_mode)) != \
                            (expected.st_dev, expected.st_ino, stat.S_IFMT(expected.st_mode)):
                        raise ValueError('Spack tree changed during ownership migration')
                    walk(child_fd, device, visitor)
                finally:
                    os.close(child_fd)

    def roots_with_devices():
        result = []
        for root in roots:
            if not os.path.isabs(root) or os.path.realpath(root) != root:
                raise ValueError('Refusing a redirected Spack tree')
            fd = os.open(root, os.O_RDONLY | os.O_NOFOLLOW | os.O_DIRECTORY)
            try:
                result.append((root, os.fstat(fd).st_dev))
            finally:
                os.close(fd)
        return result

    checked_roots = roots_with_devices()
    internal_links = {}

    def count_links(_fd, info):
        if stat.S_ISREG(info.st_mode):
            key = (info.st_dev, info.st_ino)
            internal_links[key] = internal_links.get(key, 0) + 1

    # Count every directory entry before changing any owner. A regular file can
    # be migrated only when every one of its links is inside these dedicated
    # trees. Package payloads legitimately use internal hard links (for example
    # ncurses terminfo aliases); links to another tree still fail closed.
    for root, device in checked_roots:
        fd = os.open(root, os.O_RDONLY | os.O_NOFOLLOW | os.O_DIRECTORY)
        try:
            walk(fd, device, count_links)
        finally:
            os.close(fd)

    def change_owner(fd, info):
        nonlocal changed
        if (info.st_uid, info.st_gid) == (uid, gid):
            return
        if stat.S_ISREG(info.st_mode) and internal_links.get((info.st_dev, info.st_ino)) != info.st_nlink:
            raise ValueError('Review hardlinked files outside the dedicated Spack trees before ownership migration')
        os.fchown(fd, uid, gid)
        changed = True

    for root, device in checked_roots:
        fd = os.open(root, os.O_RDONLY | os.O_NOFOLLOW | os.O_DIRECTORY)
        try:
            walk(fd, device, change_owner)
        finally:
            os.close(fd)
    return changed


if __name__ == '__main__':
    try:
        account = pwd.getpwnam(sys.argv[1])
        print('HPC_CHANGED=' + str(int(migrate(sys.argv[2:], account.pw_uid, account.pw_gid))))
    except (OSError, ValueError, KeyError) as error:
        sys.exit(str(error))
