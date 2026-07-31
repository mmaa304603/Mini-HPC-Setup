#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

source "$REPO_ROOT/tests/config/test_config.sh"

failures=0

pass() {
    echo "PASS: $1"
}

fail() {
    echo "FAIL: $1" >&2
    failures=$((failures + 1))
}

assert_file() {
    local path="$1"
    local label="$2"

    if [ -f "$path" ]; then
        pass "$label exists"
    else
        fail "$label missing: $path"
    fi
}

assert_contains() {
    local path="$1"
    local pattern="$2"
    local label="$3"

    if grep -Eq "$pattern" "$path"; then
        pass "$label"
    else
        fail "$label not found in ${path#$REPO_ROOT/}"
    fi
}

assert_literal() {
    local path="$1"
    local text="$2"
    local label="$3"

    if grep -Fq "$text" "$path"; then
        pass "$label"
    else
        fail "$label not found in ${path#$REPO_ROOT/}"
    fi
}

SPACK_INSTALLER="$TEST_SRC_SHELL_DIR/components/spack/install/install_system_spack.sh"
SPACK_CONFIG="$TEST_SRC_SHELL_DIR/components/spack/config/setup_system_spack_config.sh"
APPTAINER_INSTALLER="$TEST_SRC_SHELL_DIR/components/apptainer/install.sh"
APPTAINER_CONFIG="$TEST_SRC_SHELL_DIR/components/apptainer/apptainer.conf"
WAREWULF_CONFIG="$TEST_SRC_SHELL_DIR/components/warewulf/warewulf.conf"
WAREWULF_CONFIGURE="$TEST_SRC_SHELL_DIR/components/warewulf/configure.sh"

assert_file "$SPACK_INSTALLER" "Spack installer"
assert_file "$SPACK_CONFIG" "Spack system config script"
assert_file "$APPTAINER_INSTALLER" "Apptainer installer"
assert_file "$APPTAINER_CONFIG" "Apptainer config"
assert_file "$WAREWULF_CONFIG" "Warewulf config"
assert_file "$WAREWULF_CONFIGURE" "Warewulf configure script"

if [ -f "$SPACK_INSTALLER" ]; then
    for package in gcc gcc-c++ gcc-gfortran make patch tar gzip bzip2 xz unzip findutils git which file; do
        assert_literal "$SPACK_INSTALLER" "$package" "Spack installer declares package $package"
    done

    assert_contains "$SPACK_INSTALLER" "configure_compute_node_spack_access" "Spack installer has compute-node access function"
    assert_contains "$SPACK_INSTALLER" "wwctl image exec" "Spack installer configures Warewulf image"
    assert_contains "$SPACK_INSTALLER" "/opt[[:space:]]+nfs4|nfs4[[:space:]]+ro" "Spack installer configures /opt NFS access"
    assert_contains "$SPACK_INSTALLER" "/etc/profile.d/spack.sh" "Spack installer installs profile script into image"
fi

if [ -f "$SPACK_CONFIG" ]; then
    assert_literal "$SPACK_CONFIG" 'export SPACK_ROOT=$SPACK_INSTALL_DIR' "Spack profile exports SPACK_ROOT"
    assert_literal "$SPACK_CONFIG" 'export SPACK_SYSTEM_CONFIG_PATH=$SPACK_CONFIG_DIR' "Spack profile exports system config path"
    assert_contains "$SPACK_CONFIG" "gcc.*g\\+\\+.*gfortran|gfortran" "Spack config validates compiler commands"
fi

if [ -f "$APPTAINER_INSTALLER" ]; then
    for package in openssl-devel libuuid-devel libseccomp-devel wget squashfs-tools cryptsetup golang git; do
        assert_contains "$APPTAINER_INSTALLER" "(^|[[:space:]])$package([[:space:]]|$)" "Apptainer installer declares package $package"
    done

    assert_contains "$APPTAINER_INSTALLER" "install_into_cpu_image" "Apptainer installer has compute-image install function"
    assert_contains "$APPTAINER_INSTALLER" "dnf -y install apptainer squashfs-tools fuse-overlayfs fakeroot" "Apptainer image install includes runtime packages"
    assert_contains "$APPTAINER_INSTALLER" "wwctl image build" "Apptainer image install rebuilds Warewulf image"
fi

if [ -f "$APPTAINER_CONFIG" ]; then
    assert_contains "$APPTAINER_CONFIG" "APPTAINER_CPU_IMAGE_ENABLED=true" "Apptainer compute image checks are enabled in config"
    assert_contains "$APPTAINER_CONFIG" "APPTAINER_CPU_IMAGE_NAME=" "Apptainer compute image name is configured"
fi

if [ -f "$WAREWULF_CONFIG" ]; then
    assert_contains "$WAREWULF_CONFIG" "path:[[:space:]]+/opt" "Warewulf exports /opt"
fi

if [ -f "$WAREWULF_CONFIGURE" ]; then
    assert_contains "$WAREWULF_CONFIGURE" "configure_shared_opt_mount_overlay" "Warewulf configures shared /opt mount overlay"
    assert_contains "$WAREWULF_CONFIGURE" "mount /opt" "Warewulf mounts /opt during node initialization"
fi

if [ "$failures" -ne 0 ]; then
    echo "Shell unit tests failed: $failures" >&2
    exit 1
fi

echo "Shell unit tests passed"
