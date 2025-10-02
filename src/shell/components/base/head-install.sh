#!/bin/bash

# Rocky Linux head node base setup
# Installs essential packages and configures system for HPC head node

# Source common functions
source "$(dirname "$0")/lib.sh"

check_root

# Rocky Linux base system setup
setup_rocky_base() {
    info "Setting up Rocky Linux base system..."
    
    # Refresh metadata and update system
    dnf -y makecache || true
    dnf -y update || {
        warn "System update encountered issues; continuing"
    }
    
    # Enable EPEL
    install_package epel-release
    
    # Install development tools
    dnf groupinstall -y "Development Tools"
    
    # Install common packages
    local packages=($(get_common_packages) $(get_network_tools) bind-utils firewalld)
    
    for pkg in "${packages[@]}"; do
        install_package "$pkg"
    done
    
    # Enable firewalld
    systemctl enable --now firewalld || warn "firewalld not enabled"
    
    info "Rocky Linux base setup completed"
}

# Head node specific setup
setup_head_node() {
    info "Installing head node specific packages..."
    local head_packages=($(get_head_packages))
    
    for pkg in "${head_packages[@]}"; do
        install_package "$pkg"
    done
    
    info "Configuring head node specific services..."
    
    # Head node services
    local head_services=("chronyd" "sshd" "httpd" "cockpit.socket")
    enable_services "${head_services[@]}"
    
    # Configure PDSH for cluster management
    configure_pdsh
}

main() {
    info "Starting Rocky Linux head node base setup..."
    
    # Setup base Rocky Linux system
    setup_rocky_base
    
    # Install head node specific packages and configure services
    setup_head_node
    
    info "Rocky Linux head node setup completed"
    info "Reboot recommended if kernel was updated"
}

main "$@"
