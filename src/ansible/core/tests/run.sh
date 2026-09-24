#!/usr/bin/env bash
set -euo pipefail

CORE_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export ANSIBLE_CONFIG="${CORE_TEST_DIR}/../../ansible.cfg"
CORE_TEST_TEMP="$(mktemp -d "${TMPDIR:-/tmp}/hpc-core-checks.XXXXXX")"
trap 'rm -rf "$CORE_TEST_TEMP"' EXIT
export ANSIBLE_HOME="${CORE_TEST_TEMP}/ansible-home"
export ANSIBLE_LOCAL_TEMP="${CORE_TEST_TEMP}/local"
export ANSIBLE_REMOTE_TEMP="${CORE_TEST_TEMP}/remote"
export ANSIBLE_BECOME_ASK_PASS=False
export PYTHONDONTWRITEBYTECODE=1

ansible-playbook "${CORE_TEST_DIR}/../playbooks/site.yml" --syntax-check
ansible-playbook "${CORE_TEST_DIR}/../playbooks/verify.yml" --syntax-check
ansible-playbook "${CORE_TEST_DIR}/../playbooks/rollback.yml" --syntax-check
ansible-playbook "${CORE_TEST_DIR}/../playbooks/gpu.yml" --syntax-check
ansible-playbook "${CORE_TEST_DIR}/../playbooks/gpu-verify.yml" --syntax-check
ansible-inventory --graph
python3 -m unittest discover -s "$CORE_TEST_DIR" -p 'test_*.py' -v
