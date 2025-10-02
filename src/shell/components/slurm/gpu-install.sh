#!/bin/bash

# Ubuntu 22.04 GPU node SLURM installation
# Installs MUNGE and SLURM compute daemon for HPC GPU nodes

# Source common functions
source "$(dirname "$0")/../../lib/functions.sh"
source "$(dirname "$0")/../../lib/config.sh"

# Load component configuration
load_component_config "slurm" 2>/dev/null || true
load_component_config "network" 2>/dev/null || true
export_config

check_root

# Install MUNGE for GPU node
install_munge() {
    info "Installing MUNGE for GPU node..."
    
    # Install MUNGE packages
    apt-get update -y
    apt-get install -y munge munge-libs
    
    # Set proper ownership and permissions
    chown -R munge: /etc/munge /var/lib/munge /var/log/munge /var/run/munge
    chmod 0700 /etc/munge /var/lib/munge
    chmod 0755 /var/log/munge /var/run/munge
    
    # Enable and start MUNGE service
    info "Starting MUNGE service..."
    systemctl enable munge
    systemctl start munge
    
    # Verify MUNGE installation
    info "Verifying MUNGE installation..."
    if munge -n | unmunge >/dev/null 2>&1; then
        info "MUNGE installation completed successfully"
    else
        error "MUNGE verification failed"
        return 1
    fi
}

# Install SLURM compute daemon
install_slurm() {
    info "Installing SLURM compute daemon..."
    
    # Install SLURM packages
    apt-get install -y slurm-wlm slurmd slurm-client
    
    info "SLURM compute daemon installed successfully"
}

# Configure SLURM compute daemon
configure_slurm() {
    info "Configuring SLURM compute daemon..."
    
    # Create SLURM directories
    mkdir -p /var/log/slurm /var/spool/slurm
    
    # Enable SLURM compute daemon
    systemctl enable --now slurmd || warn "slurmd enable/start failed (may require config first)"
    
    info "SLURM compute daemon configuration completed"
}

main() {
    info "Starting Ubuntu 22.04 GPU node SLURM setup..."
    
    # Install MUNGE first (SLURM prerequisite)
    install_munge
    
    # Install and configure SLURM compute daemon
    install_slurm
    configure_slurm
    
    info "GPU node SLURM setup completed successfully"
    info "Ensure MUNGE key matches the head node for authentication"
}

main "$@"
