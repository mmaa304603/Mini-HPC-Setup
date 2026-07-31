#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source "$REPO_ROOT/tests/config/test_config.sh"

SHELL_DIR="$TEST_SRC_SHELL_DIR"
failures=0
skips=0

pass() {
    echo "PASS: $1"
}

fail() {
    echo "FAIL: $1" >&2
    failures=$((failures + 1))
}

skip() {
    echo "SKIP: $1"
    skips=$((skips + 1))
}

command_available() {
    command -v "$1" >/dev/null 2>&1
}

remote_check() {
    local node="$1"
    local description="$2"
    local remote_command="$3"

    if ssh $HPC_TEST_SSH_OPTS "${node}" "$remote_command" >/dev/null 2>&1; then
        pass "$description is available on compute node $node"
    else
        fail "$description is missing or unreachable on compute node $node"
    fi
}

load_shell_configs() {
    [ -f "$SHELL_DIR/components/slurm/slurm.conf" ] && source "$SHELL_DIR/components/slurm/slurm.conf"
}

compute_nodes_from_config() {
    if [ -n "$HPC_TEST_COMPUTE_NODES" ]; then
        printf '%s\n' $HPC_TEST_COMPUTE_NODES
        return 0
    fi

    if [ "$HPC_TEST_ENABLE_COMPUTE" = "1" ]; then
        declare -p SLURM_CPU_NODES >/dev/null 2>&1 && printf '%s\n' "${SLURM_CPU_NODES[@]}"
        declare -p SLURM_GPU_NODES >/dev/null 2>&1 && printf '%s\n' "${SLURM_GPU_NODES[@]}"
    fi
}

check_srun_node() {
    local node="$1"

    if ! command_available srun; then
        fail "srun command is missing on head node"
        return 0
    fi

    if srun $HPC_TEST_SRUN_OPTS -N1 -n1 -w "$node" hostname >/dev/null 2>&1; then
        pass "srun can launch on compute node $node"
    else
        fail "srun cannot launch on compute node $node"
    fi
}

check_runtime_nodes() {
    local nodes=()
    local node

    mapfile -t nodes < <(compute_nodes_from_config)
    if [ "${#nodes[@]}" -eq 0 ]; then
        skip "runtime node checks disabled; set HPC_TEST_COMPUTE_NODES or HPC_TEST_ENABLE_COMPUTE=1"
        return 0
    fi

    for node in "${nodes[@]}"; do
        [ -n "$node" ] || continue

        remote_check "$node" "SSH command execution" "true"

        if [[ " $HPC_TEST_COMPONENTS " == *" spack "* ]]; then
            remote_check "$node" "Spack runtime access" "findmnt --mountpoint /opt >/dev/null && bash -lc 'source /etc/profile.d/spack.sh && command -v spack && spack --version'"
        fi

        if [[ " $HPC_TEST_COMPONENTS " == *" apptainer "* ]]; then
            remote_check "$node" "Apptainer runtime access" "command -v apptainer && apptainer --version"
        fi

        check_srun_node "$node"
    done
}

load_shell_configs
check_runtime_nodes

echo "Shell runtime tests completed: failures=$failures skips=$skips"

if [ "$failures" -ne 0 ]; then
    exit 1
fi
