#!/bin/bash

# Rocky Linux head node SLURM installation
# Installs MUNGE and SLURM controller for HPC head node

# Source common functions
source "$(dirname "$0")/../../lib/functions.sh"
source "$(dirname "$0")/../../lib/config.sh"

# Load component configuration
load_component_config "slurm" 2>/dev/null || true
load_component_config "network" 2>/dev/null || true
export_config

check_root

# Install MUNGE for head node
install_munge() {
    info "Installing MUNGE for head node..."
    
    # Install MUNGE packages
    dnf install -y munge munge-libs
    
    # Generate munge key
    info "Generating MUNGE key..."
    /usr/sbin/create-munge-key
    
    # Enable and start MUNGE service
    info "Starting MUNGE service..."
    systemctl enable munge
    systemctl start munge
    
    # Verify MUNGE installation
    info "Verifying MUNGE installation..."
    if munge -n | unmunge >/dev/null 2>&1; then
        info "MUNGE installation completed successfully"
        info "MUNGE key location: /etc/munge/munge.key"
    else
        error "MUNGE verification failed"
        return 1
    fi
}

# Install SLURM controller
install_slurm() {
    info "Installing SLURM controller..."
    
    # Install EPEL repository
    dnf install -y epel-release
    
    # Install SLURM packages
    dnf install -y slurm slurmctld slurm-devel
    
    info "SLURM controller installed successfully"
}

# Configure SLURM controller
configure_slurm() {
    info "Configuring SLURM controller..."
    
    # Create SLURM directories
    mkdir -p /etc/slurm /var/log/slurm /var/spool/slurm/state
    chown -R slurm:slurm /var/log/slurm /var/spool/slurm || true
    
    # Enable SLURM controller
    systemctl enable --now slurmctld || warn "slurmctld enable/start failed (may require config first)"
    
    info "SLURM controller configuration completed"
    info "Use ./configure.sh to generate slurm.conf and deploy"
}

main() {
    info "Starting Rocky Linux head node SLURM setup..."
    
    # Install MUNGE first (SLURM prerequisite)
    install_munge
    
    # Install and configure SLURM controller
    install_slurm
    configure_slurm
    
    info "Head node SLURM setup completed successfully"
    info "Copy /etc/munge/munge.key to all compute nodes for authentication"
}

main "$@"
