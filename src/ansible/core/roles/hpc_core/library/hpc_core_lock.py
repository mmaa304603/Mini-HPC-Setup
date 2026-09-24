#!/usr/bin/python
"""Exclusive deployment ownership across Ansible module processes.

A killed controller leaves the lock in place deliberately: elapsed time cannot
prove an installer has stopped. Ordinary task failures release it through
block/always. Fatal Ansible handlers and unreachable hosts can bypass that cleanup;
retained ownership requires inspection instead of automatic expiration.
"""
import json
import os
import secrets
import stat
from ansible.module_utils.basic import AnsibleModule


def execute(directory, state, token=''):
    if not os.path.isabs(directory) or os.path.realpath(directory) != directory or directory == '/':
        raise ValueError('Lock path must be canonical and absolute without symlinks')
    if state == 'acquire':
        try:
            os.mkdir(directory, 0o700)
        except FileExistsError:
            raise ValueError('Deployment lock already exists: %s. Another run may be active. '
                             'After confirming all installers have stopped, recover the lock manually; '
                             'never remove it merely because it is old.' % directory)
        token = secrets.token_hex(32)
        try:
            fd = os.open(directory + '/owner.json', os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            with os.fdopen(fd, 'w') as stream:
                json.dump({'token': token}, stream)
        except Exception:
            # An incomplete lock still excludes other deployments; fail closed.
            raise
        return dict(changed=True, token=token)
    info = os.lstat(directory)
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.geteuid() or stat.S_IMODE(info.st_mode) != 0o700:
        raise ValueError('Unsafe deployment lock directory')
    path = directory + '/owner.json'
    info = os.lstat(path)
    if not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid() or stat.S_IMODE(info.st_mode) != 0o600:
        raise ValueError('Unsafe deployment lock owner record')
    with open(path) as stream:
        owner = json.load(stream)
    if not token or not secrets.compare_digest(token, owner['token']):
        raise ValueError('Deployment lock belongs to another run')
    if state == 'release':
        os.unlink(path)
        os.rmdir(directory)
    return dict(changed=state == 'release')


def main():
    module = AnsibleModule(argument_spec=dict(directory=dict(required=True, type='path'),
        state=dict(required=True, choices=['acquire', 'check', 'release']), token=dict(default='', no_log=True)))
    try:
        module.exit_json(**execute(**module.params))
    except (OSError, ValueError, KeyError) as exc:
        module.fail_json(msg=str(exc))


if __name__ == '__main__':
    main()
