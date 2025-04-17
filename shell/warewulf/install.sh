#!/bin/bash

# Source common functions
source "$(dirname "$0")/../common/functions.sh"

# Install Warewulf
install_warewulf() {
    info "Installing Warewulf..."
    
    # Add Warewulf repository
    dnf install -y epel-release
    dnf install -y https://github.com/hpcng/warewulf/releases/download/v4.6.0/warewulf-4.6.0.el9.x86_64.rpm
    
    # Install required packages
    dnf install -y tftp-server dhcp-server nfs-utils
    
    info "Warewulf installed successfully"
}

# Configure Warewulf
configure_warewulf() {
    info "Configuring Warewulf..."
    
    # Copy configuration file
    cp "$(dirname "$0")/warewulf.conf" /etc/warewulf/warewulf.conf
    
    # Initialize Warewulf
    wwctl configure --all
    
    # Start and enable services
    systemctl enable --now warewulfd
    systemctl enable --now dhcpd
    systemctl enable --now tftp
    systemctl enable --now nfs-server
    
    info "Warewulf configured successfully"
}

# Main execution
main() {
    check_root
    
    install_warewulf
    configure_warewulf
    
    info "Warewulf installation and configuration completed successfully"
}

main "$@" 