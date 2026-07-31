#!/bin/bash
set -euo pipefail

# Source common functions
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

source "${SCRIPT_DIR}/../../lib/functions.sh"
source "${SCRIPT_DIR}/../../lib/config.sh"

load_component_config "apptainer"

# Check if running as root
check_root

join_by_comma() {
    local IFS=,
    echo "$*"
}

# Install dependencies
install_dependencies() {
    info "Installing dependencies..."
    
    # Basic development tools
    dnf groupinstall -y "Development Tools"
    
    # Required packages
    local packages=(
        openssl-devel
        libuuid-devel
        libseccomp-devel
        wget
        squashfs-tools
        cryptsetup
        golang
        git
    )

    for package in "${packages[@]}"; do
        install_package "$package"
    done
}

# Download and install Apptainer
install_apptainer() {
    local prefix="$1"
    local build_dir
    local gocache
    local goflags

    if command -v apptainer >/dev/null 2>&1 &&
        apptainer --version 2>/dev/null | grep -q "apptainer version ${APPTAINER_VERSION}"; then
        info "Apptainer ${APPTAINER_VERSION} is already installed"
        return 0
    fi

    info "Installing Apptainer ${APPTAINER_VERSION}..."

    build_dir="$(mktemp -d)"
    gocache="${build_dir}/go-cache"
    trap 'rm -rf "$build_dir"' RETURN

    mkdir -p "$gocache"

    cd "$build_dir"
    wget "https://github.com/apptainer/apptainer/releases/download/v${APPTAINER_VERSION}/apptainer-${APPTAINER_VERSION}.tar.gz"
    tar -xzf "apptainer-${APPTAINER_VERSION}.tar.gz"
    cd "apptainer-${APPTAINER_VERSION}"

    goflags="${GOFLAGS:-}"
    if [[ " $goflags " != *" -buildvcs=false "* ]]; then
        goflags="${goflags:+$goflags }-buildvcs=false"
    fi

    ./mconfig --prefix="$prefix"
    GOCACHE="$gocache" make -C builddir GOFLAGS="$goflags"
    GOCACHE="$gocache" make -C builddir install GOFLAGS="$goflags"

    trap - RETURN
    rm -rf "$build_dir"
}

expose_apptainer_command() {
    local installed_bin="${APPTAINER_INSTALL_PREFIX}/bin/apptainer"
    local system_bin="/usr/bin/apptainer"

    if command -v apptainer >/dev/null 2>&1; then
        return 0
    fi

    if [ ! -x "$installed_bin" ]; then
        error "Apptainer was not installed at expected path: $installed_bin"
        return 1
    fi

    info "Exposing Apptainer command at ${system_bin}..."
    ln -sfn "$installed_bin" "$system_bin"
}

# Configure Apptainer for HPC
configure_apptainer() {
    local bind_path

    info "Configuring Apptainer..."

    bind_path="$(join_by_comma "${APPTAINER_BIND_PATHS[@]}")"

    mkdir -p "$APPTAINER_SYSCONFDIR" "$APPTAINER_CACHE_DIR" "$(dirname "$APPTAINER_SYSCONFIG")"

    cat > "${APPTAINER_SYSCONFDIR}/apptainer.conf" << EOF
# Apptainer configuration file

# Allow containers to use bind mounts
mount devpts = yes
mount proc = yes
mount sys = yes
mount home = yes
mount tmp = yes
mount hostfs = yes
mount scratch = yes

# Enable overlay fs for better performance
enable overlay = yes

# Allow use of NVIDIA GPUs
enable nv = yes

# Allow use of Rocm/AMD GPUs
enable rocm = yes

# Network configuration
allow net = yes
allow network = yes

# MPI configuration
mpi config file = ${APPTAINER_SYSCONFDIR}/mpi.conf

# Limit container resources
limit container groups = 65536
limit container owners = @wheel
EOF
    
    # Create MPI configuration
    cat > "${APPTAINER_SYSCONFDIR}/mpi.conf" << EOF
# MPI configuration for Apptainer containers

# OpenMPI settings
openmpi_prefix = /usr/lib64/openmpi
openmpi_modulefile = /etc/modulefiles/mpi/openmpi

# MPICH settings
mpich_prefix = /usr/lib64/mpich
mpich_modulefile = /etc/modulefiles/mpi/mpich
EOF

    cat > "$APPTAINER_SYSCONFIG" << EOF
# System-wide Apptainer configuration

# Allow unprivileged users to use FUSE mounts
APPTAINER_BIND_PATH="${bind_path}"
APPTAINER_ALLOW_FUSEMOUNT=1

# Enable container overlay support
APPTAINER_ENABLE_OVERLAY=1

# Cache directory
APPTAINER_CACHEDIR="${APPTAINER_CACHE_DIR}"

# Temp directory
APPTAINER_TMPDIR="/tmp"

# Allow users to use GPU devices
APPTAINER_NV=1
APPTAINER_ROCM=1
EOF

    chmod 644 "${APPTAINER_SYSCONFDIR}"/*.conf "$APPTAINER_SYSCONFIG"
    chmod 755 "$APPTAINER_CACHE_DIR"
}

# Create environment module file
create_module_file() {
    local bind_path

    [ "$APPTAINER_MODULE_ENABLED" = true ] || return 0

    info "Creating Apptainer environment module..."

    bind_path="$(join_by_comma "${APPTAINER_BIND_PATHS[@]}")"
    mkdir -p "$APPTAINER_MODULE_DIR"

    cat > "${APPTAINER_MODULE_DIR}/apptainer" << EOF
#%Module1.0
proc ModulesHelp { } {
    puts stderr "This module loads Apptainer container runtime"
    puts stderr "Version ${APPTAINER_VERSION}"
}

module-whatis "Loads Apptainer container runtime"

# Environment setup
setenv APPTAINER_VERSION "${APPTAINER_VERSION}"
setenv APPTAINER_CACHEDIR "${APPTAINER_CACHE_DIR}"
setenv APPTAINER_BINDPATH "${bind_path}"

prepend-path PATH "${APPTAINER_INSTALL_PREFIX}/bin"
prepend-path MANPATH "${APPTAINER_INSTALL_PREFIX}/share/man"
EOF

    chmod 644 "${APPTAINER_MODULE_DIR}/apptainer"
}

# Create example container recipes
create_example_recipes() {
    local recipe_dir="${APPTAINER_INSTALL_PREFIX}/share/apptainer/examples"

    info "Creating example container recipes..."

    mkdir -p "$recipe_dir"

    cat > "${recipe_dir}/openmpi.def" << EOF
Bootstrap: docker
From: rockylinux:9

%post
    dnf -y update
    dnf -y groupinstall "Development Tools"
    dnf -y install openmpi openmpi-devel

%environment
    export OMPI_DIR=/usr/lib64/openmpi
    export PATH=\$OMPI_DIR/bin:\$PATH
    export LD_LIBRARY_PATH=\$OMPI_DIR/lib:\$LD_LIBRARY_PATH
    export MANPATH=\$OMPI_DIR/share/man:\$MANPATH

%runscript
    /usr/bin/mpirun --version
EOF

    chmod 644 "${recipe_dir}/openmpi.def"
}

install_into_cpu_image() {
    [ "$APPTAINER_CPU_IMAGE_ENABLED" = true ] || return 0

    if ! command -v wwctl >/dev/null 2>&1; then
        warn "wwctl not found; skipping Apptainer install in Warewulf CPU image"
        return 0
    fi

    if ! wwctl image list | grep -q "$APPTAINER_CPU_IMAGE_NAME"; then
        warn "Warewulf image $APPTAINER_CPU_IMAGE_NAME not found; skipping compute image install"
        return 0
    fi

    info "Installing Apptainer into Warewulf image ${APPTAINER_CPU_IMAGE_NAME}..."

    wwctl image exec "$APPTAINER_CPU_IMAGE_NAME" -- /bin/bash -lc "
        set -euo pipefail
        dnf -y install dnf-plugins-core || true
        dnf -y install epel-release || true
        dnf config-manager --set-enabled crb || true
        dnf makecache -y || true
        dnf -y install apptainer squashfs-tools fuse-overlayfs fakeroot
        command -v apptainer
        rpm -q squashfs-tools fuse-overlayfs fakeroot
        mkdir -p '${APPTAINER_SYSCONFDIR}' '${APPTAINER_CACHE_DIR}' '$(dirname "$APPTAINER_SYSCONFIG")'
    "

    wwctl image exec \
        --bind "${APPTAINER_SYSCONFDIR}/apptainer.conf:/tmp/apptainer.conf:ro" \
        --bind "${APPTAINER_SYSCONFDIR}/mpi.conf:/tmp/mpi.conf:ro" \
        --bind "${APPTAINER_SYSCONFIG}:/tmp/apptainer.sysconfig:ro" \
        "$APPTAINER_CPU_IMAGE_NAME" -- /bin/bash -lc "
            set -euo pipefail
            install -D -m 0644 /tmp/apptainer.conf '${APPTAINER_SYSCONFDIR}/apptainer.conf'
            install -D -m 0644 /tmp/mpi.conf '${APPTAINER_SYSCONFDIR}/mpi.conf'
            install -D -m 0644 /tmp/apptainer.sysconfig '${APPTAINER_SYSCONFIG}'
            chmod 755 '${APPTAINER_CACHE_DIR}'
        "

    wwctl image build "$APPTAINER_CPU_IMAGE_NAME"
    wwctl overlay build
}

main() {
    ensure_dir "$LOG_DIR"
    
    info "Starting Apptainer installation..."
    
    install_dependencies
    install_apptainer "$APPTAINER_INSTALL_PREFIX"
    expose_apptainer_command
    configure_apptainer
    create_module_file
    create_example_recipes
    install_into_cpu_image

    info "Apptainer setup completed"
}

main "$@"
