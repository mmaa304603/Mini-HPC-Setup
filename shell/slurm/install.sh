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

# Install SLURM packages
install_slurm_packages() {
    info "Installing SLURM packages..."
    
    local packages=(
        "slurm"
        "slurm-devel"
        "slurm-perlapi"
    )
    
    for package in "${packages[@]}"; do
        install_package "$package"
    done
}

# Create SLURM directories
create_slurm_dirs() {
    info "Creating SLURM directories..."
    
    local dirs=(
        "/etc/slurm"
        "/var/log/slurm"
        "/var/spool/slurm"
    )
    
    for dir in "${dirs[@]}"; do
        ensure_dir "$dir"
        chmod 755 "$dir"
    done
}

# Install Munge for authentication
install_munge() {
    info "Installing Munge..."
    
    # Install Munge package
    install_package "munge"
    
    # Generate Munge key if it doesn't exist
    if [ ! -f "/etc/munge/munge.key" ]; then
        info "Generating Munge key..."
        dd if=/dev/urandom bs=1 count=1024 > /etc/munge/munge.key
        chmod 400 /etc/munge/munge.key
    fi
    
    # Start and enable Munge service
    start_service "munge"
}

# Main execution
main() {
    ensure_dir "$LOG_DIR"
    
    # Install dependencies
    install_epel
    install_slurm_packages
    install_munge
    
    # Create directories
    create_slurm_dirs
    
    info "SLURM installation completed successfully"
}

main "$@" 