#!/usr/bin/env bash
set -euo pipefail
COMPONENT_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPONENT_TEST_TEMP="$(mktemp -d "${TMPDIR:-/tmp}/hpc-component-tests.XXXXXX")"
trap 'rm -rf "$COMPONENT_TEST_TEMP"' EXIT
export ANSIBLE_CONFIG="${COMPONENT_TEST_DIR}/../../ansible.cfg"
export ANSIBLE_HOME="${COMPONENT_TEST_TEMP}/ansible-home"
export ANSIBLE_LOCAL_TEMP="${COMPONENT_TEST_TEMP}/local"
export ANSIBLE_REMOTE_TEMP="${COMPONENT_TEST_TEMP}/remote"
export PYTHONDONTWRITEBYTECODE=1
export ANSIBLE_BECOME_ASK_PASS=False

# Import real task files statically: core's dynamic includes alone do not check them.
python3 - "$COMPONENT_TEST_DIR" "$COMPONENT_TEST_TEMP" <<'PY'
from pathlib import Path
import sys
import yaml
components = Path(sys.argv[1]).parent
tasks = []
for role, phases in {
    "warewulf": ["security", "head", "image_prepare", "publish", "verify", "rollback"],
    "slurm": ["head", "cpu_image", "verify"],
    "spack": ["head", "cpu_image", "verify"],
    "lmod": ["head", "cpu_image", "verify"],
    "jetson": ["preflight", "deploy", "verify"],
}.items():
    for phase in phases:
        tasks.append({"ansible.builtin.import_role": {
            "name": str(components / role), "tasks_from": phase}})
play = [{"name": "Component syntax only", "hosts": "headnode",
         "gather_facts": False, "tasks": tasks}]
(Path(sys.argv[2]) / "syntax.yml").write_text(yaml.safe_dump(play))
PY
ansible-playbook "${COMPONENT_TEST_TEMP}/syntax.yml" --syntax-check
python3 -m unittest discover -s "$COMPONENT_TEST_DIR" -p 'test_*.py' -v
