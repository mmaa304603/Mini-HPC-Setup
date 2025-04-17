#!/bin/bash

# Source common functions
source "$(dirname "$0")/../common/functions.sh"

# Check if running as root
check_root

# Install EPEL repository
install_epel() {
    info "Installing EPEL repository..."
    install_package "epel-release"
}

# Install Warewulf repository
install_warewulf_repo() {
    info "Installing Warewulf repository..."
    
    local repo_url="https://warewulf.org/downloads/warewulf-release-${WAREWULF_VERSION}.el8.noarch.rpm"
    local repo_file="/tmp/warewulf-release.rpm"
    
    # Download repository package
    curl -L "$repo_url" -o "$repo_file" || {
        error "Failed to download Warewulf repository package"
        return 1
    }
    
    # Install repository package
    dnf install -y "$repo_file" || {
        error "Failed to install Warewulf repository package"
        return 1
    }
    
    # Clean up
    rm -f "$repo_file"
}

# Install Warewulf packages
install_warewulf_packages() {
    info "Installing Warewulf packages..."
    
    local packages=(
        "warewulf-server"
        "warewulf-client"
        "warewulf-common"
    )
    
    for package in "${packages[@]}"; do
        install_package "$package"
    done
}

# Configure firewall for Warewulf
configure_warewulf_firewall() {
    info "Configuring firewall for Warewulf..."
    configure_firewall "$WAREWULF_PORT" "warewulf"
}

# Start Warewulf services
start_warewulf_services() {
    info "Starting Warewulf services..."
    
    local services=(
        "warewulfd"
        "dhcpd"
        "tftp"
    )
    
    for service in "${services[@]}"; do
        start_service "$service"
    done
}

# Main execution
main() {
    ensure_dir "$LOG_DIR"
    
    # Install dependencies
    install_epel
    install_warewulf_repo
    install_warewulf_packages
    
    # Configure firewall
    configure_warewulf_firewall
    
    # Start services
    start_warewulf_services
    
    info "Warewulf installation completed successfully"
}

main "$@" 