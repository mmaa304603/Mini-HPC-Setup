#!/usr/bin/env bash

set -euo pipefail

SETUP_TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ANSIBLE_CONFIG="${SETUP_TEST_DIR}/ansible.cfg"
export ANSIBLE_LOCAL_TEMP="${TMPDIR:-/tmp}/bansible-ansible-local"
export ANSIBLE_REMOTE_TEMP="${TMPDIR:-/tmp}/bansible-ansible-remote"

ansible-doc ansible.posix.selinux >/dev/null
ansible-doc community.general.nmcli >/dev/null

ansible-playbook "${SETUP_TEST_DIR}/playbooks/init.yml" --syntax-check

ansible-inventory --graph >/dev/null

ansible-playbook \
    -i "${SETUP_TEST_DIR}/inventory/test" \
    "${SETUP_TEST_DIR}/playbooks/init.yml" \
    --list-tasks >/dev/null

echo "bansible setup structure checks passed"
