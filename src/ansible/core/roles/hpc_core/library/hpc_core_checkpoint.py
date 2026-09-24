#!/usr/bin/python
"""Private, atomic phase receipts. No component execution or secret persistence."""
import datetime
import hashlib
import json
import os
import re
import stat
import tempfile
import subprocess

from ansible.module_utils.basic import AnsibleModule


FACT_KEYS = {
    'slurm-head': {'slurm_rpm_release', 'slurm_controller_hostname', 'slurm_job_identity'},
    'lmod-head': {'lmod_rpm_release', 'hpc_spack_module_test'},
}


def normalize_facts(facts):
    """Ansible's non-native templating can serialize `| int` facts as strings.

    Normalize only decimal UID/GID strings; leave bools, floats and malformed
    strings untouched so strict validation still rejects them. Do not mutate
    the caller's facts or coerce arbitrary checkpoint fields.
    """
    if not isinstance(facts, dict):
        return facts
    normalized = dict(facts)
    identity = facts.get('slurm_job_identity')
    if isinstance(identity, dict):
        identity = dict(identity)
        for key in ('uid', 'gid'):
            value = identity.get(key)
            if isinstance(value, str) and re.fullmatch(r'[0-9]+', value):
                identity[key] = int(value)
        normalized['slurm_job_identity'] = identity
    return normalized


def valid_facts(phase, facts):
    if not isinstance(facts, dict) or set(facts) != FACT_KEYS.get(phase, set()):
        return False
    for key in ('slurm_rpm_release', 'slurm_controller_hostname', 'lmod_rpm_release'):
        if key in facts and (not isinstance(facts[key], str) or not facts[key]):
            return False
    if 'slurm_job_identity' in facts:
        identity = facts['slurm_job_identity']
        if not isinstance(identity, dict) or set(identity) != {'name', 'group', 'uid', 'gid'}:
            return False
        if any(not isinstance(identity[k], str) or not identity[k] for k in ('name', 'group')):
            return False
        if (type(identity['uid']) is not int or identity['uid'] < 1000 or
                type(identity['gid']) is not int or identity['gid'] < 0):
            return False
    if 'hpc_spack_module_test' in facts:
        contract = facts['hpc_spack_module_test']
        if not isinstance(contract, dict) or set(contract) != {'module_path', 'name', 'prefix', 'command'}:
            return False
        if any(not isinstance(contract[k], str) or not contract[k] for k in ('module_path', 'name', 'prefix')):
            return False
        if not isinstance(contract['command'], list) or not contract['command'] or any(
                not isinstance(arg, str) for arg in contract['command']):
            return False
    return True


def private_path(path, directory=False):
    info = os.lstat(path)
    expected = stat.S_ISDIR if directory else stat.S_ISREG
    if not expected(info.st_mode) or info.st_uid != os.geteuid() or stat.S_IMODE(info.st_mode) != (0o700 if directory else 0o600):
        raise ValueError('Checkpoint path must be a private, effective-user-owned %s: %s' % (
            'directory (0700)' if directory else 'regular file (0600)', path))


def read_receipt(path, item):
    if not os.path.lexists(path):
        return None
    private_path(path)
    try:
        with open(path, encoding='utf-8') as stream:
            receipt = json.load(stream)
    except (ValueError, UnicodeError):
        return None
    if not isinstance(receipt, dict) or receipt.get('schema_version') != 1:
        return None
    if any(receipt.get(k) != item[k] for k in ('phase', 'fingerprint')):
        return None
    receipt['facts'] = normalize_facts(receipt.get('facts'))
    return receipt if valid_facts(item['phase'], receipt['facts']) else None


def observe(probes):
    """Capture stable state, never file contents or command output in receipts."""
    result = {}
    paths = list(probes.get('paths', []))
    for tree in probes.get('trees', []):
        if not os.path.isdir(tree):
            raise ValueError('Missing checkpoint artifact tree: ' + tree)
        for directory, dirs, files in os.walk(tree, followlinks=False):
            paths.append(directory)
            paths.extend(os.path.join(directory, name) for name in files)
    for path in sorted(paths):
        info = os.stat(path)
        item = [info.st_mode, info.st_uid, info.st_gid]
        if stat.S_ISREG(info.st_mode):
            digest = hashlib.sha256()
            with open(path, 'rb') as stream:
                for block in iter(lambda: stream.read(1024 * 1024), b''):
                    digest.update(block)
            item.append(digest.hexdigest())
        elif not stat.S_ISDIR(info.st_mode):
            raise ValueError('Unsupported checkpoint artifact: ' + path)
        result[path] = item
    for argv in probes.get('commands', []):
        command = subprocess.run(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60)
        if command.returncode:
            raise ValueError('Checkpoint health probe failed: ' + argv[0])
        result[json.dumps(argv)] = hashlib.sha256(command.stdout).hexdigest()
    return result


def sync_directory(directory):
    fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def execute(params):
    directory = params['directory']
    if not os.path.isabs(directory) or os.path.realpath(directory) != directory or directory == '/':
        raise ValueError('Checkpoint directory must be an absolute, canonical path without symlinks')
    created = not os.path.exists(directory)
    if created:
        os.makedirs(directory, mode=0o700)
    private_path(directory, directory=True)
    plan = params['plan']
    if not plan or any(not re.fullmatch(r'[a-z][a-z0-9_]*-[a-z][a-z0-9_]*', p['phase']) or
                       not re.fullmatch(r'[0-9a-f]{64}', p['fingerprint']) for p in plan):
        raise ValueError('Invalid checkpoint plan')
    if len({p['phase'] for p in plan}) != len(plan):
        raise ValueError('Duplicate checkpoint phases')
    if params['state'] == 'prepare':
        skipped, facts = [], {}
        if params['resume']:
            for item in plan:
                receipt = read_receipt(os.path.join(directory, item['phase'] + '.json'), item)
                if receipt is None:
                    break
                try:
                    if receipt.get('observed') != observe(params.get('probes', {}).get(item['phase'], {})):
                        break
                except (OSError, ValueError, subprocess.TimeoutExpired):
                    break
                skipped.append(item['phase'])
                facts.update(receipt['facts'])
        # Invalidate the entire suffix BEFORE any installer runs. Also invalidate
        # unselected phases so an interrupted partial run cannot resurrect them.
        removed = []
        for name in os.listdir(directory):
            if name.endswith('.json') and name[:-5] not in skipped:
                path = os.path.join(directory, name)
                private_path(path)
                os.unlink(path)
                removed.append(name)
        if removed:
            sync_directory(directory)
        return dict(changed=created or bool(removed), skipped=skipped,
                    restored_facts=facts, invalidated=sorted(removed))
    item = next((p for p in plan if p['phase'] == params['phase']), None)
    facts = normalize_facts(params['facts'])
    if item is None or not valid_facts(item['phase'], facts):
        raise ValueError('Missing or invalid allowlisted checkpoint facts for %s' % params['phase'])
    receipt = dict(item, schema_version=1, facts=facts,
                   observed=observe(params.get('probes', {}).get(item['phase'], {})),
                   completed_at=datetime.datetime.now(datetime.timezone.utc).isoformat())
    path = os.path.join(directory, item['phase'] + '.json')
    if os.path.lexists(path):
        private_path(path)
    fd, temporary = tempfile.mkstemp(prefix='.receipt-', dir=directory)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as stream:
            json.dump(receipt, stream, sort_keys=True, indent=2)
            stream.write('\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
        sync_directory(directory)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    return dict(changed=True, phase=item['phase'], checkpoint=path)


def main():
    module = AnsibleModule(argument_spec=dict(
        directory=dict(type='path', required=True),
        state=dict(choices=['prepare', 'save'], required=True),
        plan=dict(type='list', elements='dict', required=True),
        resume=dict(type='bool', default=False),
        phase=dict(type='str', default=''),
        facts=dict(type='dict', default={}),
        probes=dict(type='dict', default={}),
    ), supports_check_mode=False)
    try:
        module.exit_json(**execute(module.params))
    except (OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired) as exc:
        module.fail_json(msg=str(exc))


if __name__ == '__main__':
    main()
