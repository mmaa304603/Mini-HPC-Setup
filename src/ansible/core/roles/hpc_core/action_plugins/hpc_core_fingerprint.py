"""Fingerprint declared inputs and executable role content, never runtime facts."""
import hashlib
import json
from pathlib import Path

import yaml
from ansible.plugins.action import ActionBase


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def role_content(directory):
    result = {}
    for folder in ('defaults', 'vars', 'tasks', 'handlers', 'templates', 'files',
                   'action_plugins', 'filter_plugins', 'library', 'meta'):
        for path in sorted((directory / folder).rglob('*')):
            if path.is_file() and '__pycache__' not in path.parts and path.suffix != '.pyc':
                result[str(path.relative_to(directory))] = hashlib.sha256(path.read_bytes()).hexdigest()
    return result


def checkpoint_plan(phases, core_role, components_dir, variables, cluster, setup):
    """Changes invalidate a suffix; all declared input changes invalidate all phases.

    Resolved declared defaults and their overrides are inputs; register/set_fact
    outputs cannot accidentally become inputs. Hash after preflight, before any
    role executes. Source hashes also cover default and task definitions.
    """
    try:
        components = Path(components_dir)
        inputs = {}
        code = {}
        for component in sorted({p['component'] for p in phases}):
            directory = components / component
            code[component] = role_content(directory)
            defaults = directory / 'defaults/main.yml'
            declared = yaml.safe_load(defaults.read_text()) if defaults.exists() else {}
            for key in declared or {}:
                if key in variables:
                    inputs[key] = variables[key]
        previous = digest({'schema': 1, 'cluster': cluster, 'setup': setup,
                           'components': sorted(code), 'inputs': inputs,
                           'core': role_content(Path(core_role))})
        result = []
        for phase in phases:
            key = phase['component'] + '-' + phase['entry']
            previous = digest({'previous': previous, 'phase': key, 'code': code[phase['component']]})
            result.append({'phase': key, 'fingerprint': previous})
        return result
    except (OSError, TypeError, ValueError) as exc:
        raise ValueError('Cannot fingerprint checkpoint inputs: %s' % exc) from exc


class ActionModule(ActionBase):
    """Resolve effective role inputs on the controller without executing roles."""
    _requires_connection = False

    def run(self, tmp=None, task_vars=None):
        result = super().run(tmp, task_vars)
        try:
            args = self._task.args
            defaults = {}
            for component in sorted({p['component'] for p in args['phases']}):
                path = Path(args['components_dir']) / component / 'defaults/main.yml'
                if path.exists():
                    defaults.update(yaml.safe_load(path.read_text()) or {})
            # Resolve nested expressions and references to other role defaults.
            # Hash effective values, not literal strings such as {{ my_packages }}.
            available = dict(defaults, **(task_vars or {}))
            templar = self._templar.copy_with_new_env(available_variables=available)
            inputs = {key: templar.template(available[key]) for key in defaults}
            result.update(changed=False, plan=checkpoint_plan(
                args['phases'], args['core_role'], args['components_dir'], inputs,
                args['cluster'], args['setup']))
        except Exception as exc:
            result.update(failed=True, msg='Cannot fingerprint deployment: %s' % exc)
        return result
