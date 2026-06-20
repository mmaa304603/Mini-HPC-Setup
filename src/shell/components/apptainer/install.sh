#!/bin/bash
set -euo pipefail

# Source common functions
# source "$(dirname "$0")/../common/functions.sh"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

source "${SCRIPT_DIR}/../../lib/functions.sh"
source "${SCRIPT_DIR}/../../lib/config.sh"

load_component_config "apptainer" 2>/dev/null || true

# Check if running as root
check_root

# Configuration
APPTAINER_VERSION="1.2.5"
APPTAINER_CONFIG_DIR="/etc/apptainer"
APPTAINER_CACHE_DIR="/var/cache/apptainer"
APPTAINER_SYSCONFIG="/etc/sysconfig/apptainer"

# Install dependencies
install_dependencies() {
    info "Installing dependencies..."
    
    # Basic development tools
    dnf groupinstall -y "Development Tools"
    
    # Required packages
    local packages=(
        "openssl-devel"
        "libuuid-devel"
        "libseccomp-devel"
        "wget"
        "squashfs-tools"
        "cryptsetup"
        "golang"
        "git"
    )
    
    for package in "${packages[@]}"; do
        install_package "$package"
    done
}

# Download and install Apptainer
install_apptainer() {
    info "Installing Apptainer ${APPTAINER_VERSION}..."
    
    # Download source
    cd /tmp
    wget https://github.com/apptainer/apptainer/releases/download/v${APPTAINER_VERSION}/apptainer-${APPTAINER_VERSION}.tar.gz
    tar -xzf apptainer-${APPTAINER_VERSION}.tar.gz
    cd apptainer-${APPTAINER_VERSION}
    
    # Build and install
    ./mconfig
    make -C builddir
    make -C builddir install
    
    info "Apptainer installation completed"
}

# Configure Apptainer for HPC
configure_apptainer() {
    info "Configuring Apptainer..."
    
    # Create configuration directories
    mkdir -p "${APPTAINER_CONFIG_DIR}"
    mkdir -p "${APPTAINER_CACHE_DIR}"
    
    # Create main configuration
    cat > "${APPTAINER_CONFIG_DIR}/apptainer.conf" << EOF
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
mpi config file = ${APPTAINER_CONFIG_DIR}/mpi.conf

# Limit container resources
limit container groups = 65536
limit container owners = @wheel
EOF
    
    # Create MPI configuration
    cat > "${APPTAINER_CONFIG_DIR}/mpi.conf" << EOF
# MPI configuration for Apptainer containers

# OpenMPI settings
openmpi_prefix = /usr/lib64/openmpi
openmpi_modulefile = /etc/modulefiles/mpi/openmpi

# MPICH settings
mpich_prefix = /usr/lib64/mpich
mpich_modulefile = /etc/modulefiles/mpi/mpich
EOF
    
    # Create system configuration
    cat > "${APPTAINER_SYSCONFIG}" << EOF
# System-wide Apptainer configuration

# Default bind paths
APPTAINER_BIND_PATH="/scratch,/work,/home"

# Allow unprivileged users to use FUSE mounts
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
    
    # Set permissions
    chmod 644 "${APPTAINER_CONFIG_DIR}"/*.conf
    chmod 644 "${APPTAINER_SYSCONFIG}"
    chmod 755 "${APPTAINER_CACHE_DIR}"
    
    info "Apptainer configuration completed"
}

# Create environment module file
create_module_file() {
    info "Creating environment module file..."
    
    local module_dir="/etc/modulefiles/container"
    mkdir -p "${module_dir}"
    
    cat > "${module_dir}/apptainer" << EOF
#%Module1.0
proc ModulesHelp { } {
    puts stderr "This module loads Apptainer container runtime"
    puts stderr "Version ${APPTAINER_VERSION}"
}

module-whatis "Loads Apptainer container runtime"

# Dependencies
prereq mpi

# Environment setup
setenv APPTAINER_VERSION "${APPTAINER_VERSION}"
setenv APPTAINER_CACHEDIR "${APPTAINER_CACHE_DIR}"
setenv APPTAINER_BINDPATH "/scratch,/work,/home"

# Add to path
prepend-path PATH "/usr/local/bin"
prepend-path MANPATH "/usr/local/share/man"
EOF
    
    chmod 644 "${module_dir}/apptainer"
    info "Module file created at ${module_dir}/apptainer"
}

# Create example container recipes
create_example_recipes() {
    info "Creating example container recipes..."
    
    local recipe_dir="/usr/local/share/apptainer/examples"
    mkdir -p "${recipe_dir}"
    
    # OpenMPI example
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
    echo "Container with OpenMPI (OMPI_VERSION: - version unidentified)"
    /usr/bin/mpirun --version
EOF
    
    # CUDA example
    cat > "${recipe_dir}/cuda.def" << EOF
Bootstrap: docker
From: nvidia/cuda:12.0.0-devel-rockylinux9

%post
    dnf -y update
    dnf -y groupinstall "Development Tools"
    dnf -y install cuda-samples

%environment
    export PATH=/usr/local/cuda/bin:\$PATH
    export LD_LIBRARY_PATH=/usr/local/cuda/lib64:\$LD_LIBRARY_PATH

%runscript
    echo "Container with CUDA (CUDA_VERSION - version unidentified"
    nvidia-smi
EOF
    
    chmod 644 "${recipe_dir}"/*.def
    info "Example recipes created in ${recipe_dir}"
}

# Main execution
main() {
    ensure_dir "$LOG_DIR"
    
    info "Starting Apptainer installation..."
    
    install_dependencies
    install_apptainer
    configure_apptainer
    create_module_file
    create_example_recipes
    
    info "Apptainer installation and configuration completed"
    info "Use 'module load container/apptainer' to get started"
}

main "$@" 