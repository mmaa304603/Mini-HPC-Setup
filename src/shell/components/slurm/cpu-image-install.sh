#!/bin/bash

# Warewulf CPU image SLURM installation
# Installs MUNGE and SLURM client in Warewulf VNFS image

# Source common functions
source "$(dirname "$0")/../../lib/functions.sh"
source "$(dirname "$0")/../../lib/config.sh"

# Load component configuration
load_component_config "slurm" 2>/dev/null || true
load_component_config "network" 2>/dev/null || true
export_config

check_root

# Install MUNGE in Warewulf image
install_munge() {
    info "Installing MUNGE in Warewulf CPU image..."
    
    # Install MUNGE packages in the image
    wwctl exec --all "dnf install -y munge munge-libs"
    
    # Set proper ownership and permissions in the image
    wwctl exec --all "chown -R munge: /etc/munge /var/lib/munge /var/log/munge /var/run/munge"
    wwctl exec --all "chmod 0700 /etc/munge /var/lib/munge"
    wwctl exec --all "chmod 0755 /var/log/munge /var/run/munge"
    
    info "MUNGE installed in Warewulf image successfully"
}

# Install SLURM client in Warewulf image
install_slurm() {
    info "Installing SLURM client in Warewulf CPU image..."
    
    # Install SLURM packages in the image
    wwctl exec --all "dnf install -y slurm-wlm slurmd slurm-client"
    
    info "SLURM client installed in Warewulf image successfully"
}

# Configure SLURM client in Warewulf image
configure_slurm() {
    info "Configuring SLURM client in Warewulf CPU image..."
    
    # Create SLURM directories in the image
    wwctl exec --all "mkdir -p /var/log/slurm /var/spool/slurm"
    
    # Enable SLURM compute daemon in the image
    wwctl exec --all "systemctl enable slurmd"
    
    info "SLURM client configuration completed in Warewulf image"
}

# Copy MUNGE key to Warewulf image
copy_munge_key() {
    info "Copying MUNGE key to Warewulf CPU image..."
    
    # Copy MUNGE key from head node to the image
    if [ -f "/etc/munge/munge.key" ]; then
        wwctl exec --all "mkdir -p /etc/munge"
        wwctl exec --all "cp /etc/munge/munge.key /etc/munge/munge.key"
        wwctl exec --all "chown munge: /etc/munge/munge.key"
        wwctl exec --all "chmod 0400 /etc/munge/munge.key"
        info "MUNGE key copied to Warewulf image successfully"
    else
        error "MUNGE key not found at /etc/munge/munge.key"
        error "Run head-install.sh first to generate the key"
        return 1
    fi
}

main() {
    info "Starting Warewulf CPU image SLURM setup..."
    
    # Check if Warewulf is running
    if ! command -v wwctl >/dev/null 2>&1; then
        error "Warewulf not found. Install Warewulf first."
        return 1
    fi
    
    # Install MUNGE in the image
    install_munge
    
    # Install SLURM client in the image
    install_slurm
    configure_slurm
    
    # Copy MUNGE key to the image
    copy_munge_key
    
    info "CPU image SLURM setup completed successfully"
    info "Rebuild and deploy the VNFS image to apply changes"
}

main "$@"
