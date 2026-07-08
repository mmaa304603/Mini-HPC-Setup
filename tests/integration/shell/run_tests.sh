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

rpm_installed() {
    command_available rpm && rpm -q "$1" >/dev/null 2>&1
}

check_local_command() {
    local command_name="$1"
    local label="$2"

    if command_available "$command_name"; then
        pass "$label command is available on head node"
    else
        fail "$label command is missing on head node: $command_name"
    fi
}

check_local_rpm_or_command() {
    local package="$1"
    local command_name="$2"
    local label="$3"

    if rpm_installed "$package" || command_available "$command_name"; then
        pass "$label is available on head node"
    else
        fail "$label is missing on head node: package=$package command=$command_name"
    fi
}

remote_check() {
    local node="$1"
    local description="$2"
    local remote_command="$3"

    if ssh $HPC_TEST_SSH_OPTS "${HPC_TEST_SSH_USER}@${node}" "$remote_command" >/dev/null 2>&1; then
        pass "$description is available on compute node $node"
    else
        fail "$description is missing or unreachable on compute node $node"
    fi
}

load_shell_configs() {
    [ -f "$SHELL_DIR/config/config.conf" ] && source "$SHELL_DIR/config/config.conf"
    [ -f "$SHELL_DIR/components/slurm/slurm.conf" ] && source "$SHELL_DIR/components/slurm/slurm.conf"
    [ -f "$SHELL_DIR/components/apptainer/apptainer.conf" ] && source "$SHELL_DIR/components/apptainer/apptainer.conf"
}

check_spack_head_node() {
    check_local_command python3 "Python 3"
    check_local_rpm_or_command gcc gcc "GCC C compiler"
    check_local_rpm_or_command gcc-c++ g++ "GCC C++ compiler"
    check_local_rpm_or_command gcc-gfortran gfortran "GCC Fortran compiler"
    check_local_command make "make"
    check_local_command git "git"

    if [ -x /opt/spack/bin/spack ]; then
        pass "Spack executable exists at /opt/spack/bin/spack"
    else
        fail "Spack executable missing at /opt/spack/bin/spack"
    fi

    if [ -f /etc/profile.d/spack.sh ]; then
        pass "Spack profile exists at /etc/profile.d/spack.sh"
    else
        fail "Spack profile missing at /etc/profile.d/spack.sh"
    fi
}

check_apptainer_head_node() {
    check_local_rpm_or_command apptainer apptainer "Apptainer runtime"
    check_local_rpm_or_command squashfs-tools unsquashfs "squashfs-tools"

    for path in "${APPTAINER_SYSCONFDIR:-/etc/apptainer}/apptainer.conf" \
                "${APPTAINER_SYSCONFDIR:-/etc/apptainer}/mpi.conf" \
                "${APPTAINER_SYSCONFIG:-/etc/sysconfig/apptainer}"; do
        if [ -f "$path" ]; then
            pass "Apptainer config exists: $path"
        else
            fail "Apptainer config missing: $path"
        fi
    done
}

compute_nodes_from_config() {
    if [ -n "$HPC_TEST_COMPUTE_NODES" ]; then
        printf '%s\n' $HPC_TEST_COMPUTE_NODES
        return 0
    fi

    if [ "$HPC_TEST_ENABLE_COMPUTE" = "1" ] && declare -p SLURM_CPU_NODES >/dev/null 2>&1; then
        printf '%s\n' "${SLURM_CPU_NODES[@]}"
    fi
}

check_compute_nodes() {
    local nodes=()
    local node

    mapfile -t nodes < <(compute_nodes_from_config)
    if [ "${#nodes[@]}" -eq 0 ]; then
        skip "compute-node package checks disabled; set HPC_TEST_COMPUTE_NODES or HPC_TEST_ENABLE_COMPUTE=1"
        return 0
    fi

    for node in "${nodes[@]}"; do
        [ -n "$node" ] || continue

        if [[ " $HPC_TEST_COMPONENTS " == *" spack "* ]]; then
            remote_check "$node" "Spack profile" "test -f /etc/profile.d/spack.sh"
            remote_check "$node" "Spack command" "bash -lc 'source /etc/profile.d/spack.sh && command -v spack'"
            remote_check "$node" "GCC compiler" "command -v gcc"
            remote_check "$node" "make" "command -v make"
            remote_check "$node" "git" "command -v git"
        fi

        if [[ " $HPC_TEST_COMPONENTS " == *" apptainer "* ]]; then
            remote_check "$node" "Apptainer command" "command -v apptainer"
            remote_check "$node" "squashfs tools" "command -v unsquashfs || rpm -q squashfs-tools"
            remote_check "$node" "Apptainer configuration" "test -f ${APPTAINER_SYSCONFDIR:-/etc/apptainer}/apptainer.conf"
        fi
    done
}

check_warewulf_image() {
    local image_name="${APPTAINER_CPU_IMAGE_NAME:-rockylinux-9.6}"
    local preflight_output

    if ! command_available wwctl; then
        skip "Warewulf image checks disabled; wwctl is not available"
        return 0
    fi

    if ! wwctl image list | grep -q "$image_name"; then
        skip "Warewulf image checks disabled; image not found: $image_name"
        return 0
    fi

    if ! preflight_output="$(wwctl image exec "$image_name" -- /bin/true 2>&1)"; then
        skip "Warewulf image checks disabled; cannot execute in image $image_name: ${preflight_output%%$'\n'*}"
        return 0
    fi

    if [[ " $HPC_TEST_COMPONENTS " == *" spack "* ]]; then
        if wwctl image exec "$image_name" -- /bin/bash -lc 'test -f /etc/profile.d/spack.sh && grep -qE "^[^#][[:space:]]+/opt[[:space:]]+" /etc/fstab'; then
            pass "Spack is exposed in Warewulf image $image_name"
        else
            fail "Spack is not exposed correctly in Warewulf image $image_name"
        fi
    fi

    if [[ " $HPC_TEST_COMPONENTS " == *" apptainer "* ]]; then
        if wwctl image exec "$image_name" -- /bin/bash -lc 'command -v apptainer && rpm -q squashfs-tools fuse-overlayfs fakeroot'; then
            pass "Apptainer packages are installed in Warewulf image $image_name"
        else
            fail "Apptainer packages are missing in Warewulf image $image_name"
        fi
    fi
}

load_shell_configs

if [[ " $HPC_TEST_COMPONENTS " == *" spack "* ]]; then
    check_spack_head_node
fi

if [[ " $HPC_TEST_COMPONENTS " == *" apptainer "* ]]; then
    check_apptainer_head_node
fi

check_warewulf_image
check_compute_nodes

echo "Shell integration tests completed: failures=$failures skips=$skips"

if [ "$failures" -ne 0 ]; then
    exit 1
fi
