#!/bin/bash

# Jetson GPU node base setup
# Installs essential packages and configures system for HPC GPU compute node

# Source common functions
source "$(dirname "$0")/lib.sh"

check_root

# Ubuntu/Jetson base system setup
setup_ubuntu_base() {
    info "Setting up Ubuntu/Jetson base system..."
    
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y || true
    apt-get dist-upgrade -y || true
    
    local packages=($(get_common_packages) $(get_network_tools) dnsutils ufw)
    
    apt-get install -y "${packages[@]}" || {
        error "Failed to install base packages"
        exit 1
    }
    
    # UFW available but not enabled by default
    if command -v ufw >/dev/null 2>&1; then
        ufw --force disable || true
    fi
    
    info "Ubuntu/Jetson base setup completed"
}

# GPU node specific setup
setup_gpu_node() {
    info "Installing GPU node specific packages..."
    local gpu_packages=($(get_gpu_packages))
    
    for pkg in "${gpu_packages[@]}"; do
        if apt-cache show "$pkg" >/dev/null 2>&1; then
            apt-get install -y "$pkg" || warn "Failed to install $pkg"
        else
            warn "Package $pkg not available, skipping"
        fi
    done
    
    info "Configuring GPU node specific services..."
    
    # GPU node services
    local gpu_services=("ssh" "chrony")
    enable_services "${gpu_services[@]}"
    
    # Configure for GPU compute
    info "Configuring GPU compute environment..."
    
    # Add user to docker group if docker is installed
    if command -v docker >/dev/null 2>&1; then
        add_user_to_group "$SUDO_USER" "docker"
    fi
}

main() {
    info "Starting Jetson GPU node base setup..."
    
    # Setup base Ubuntu/Jetson system
    setup_ubuntu_base
    
    # Install GPU node specific packages and configure services
    setup_gpu_node
    
    info "Jetson GPU node setup completed"
    info "Reboot recommended if kernel was updated"
}

main "$@"
