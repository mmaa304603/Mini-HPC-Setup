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

# Allow compute nodes to synchronize their clocks with the head node.
configure_time_server() {
    local cluster_network="${CLUSTER_NETWORK_CIDR:-10.0.0.0/22}"

    info "Configuring head node as time server for ${cluster_network}..."

    dnf install -y chrony

    if ! grep -Fqx "allow ${cluster_network}" /etc/chrony.conf; then
        printf '\nallow %s\n' "$cluster_network" >> /etc/chrony.conf
    fi

    # The compute nodes use this host as their NTP source. The standalone
    # network setup normally opens this service, but hpc-setup may skip that
    # step when Warewulf manages the network.
    if systemctl is-active --quiet firewalld; then
        firewall-cmd --permanent --add-service=ntp
        firewall-cmd --reload
    fi

    systemctl enable --now chronyd
    systemctl restart chronyd
}

# Install MUNGE for head node
install_munge() {
    info "Installing MUNGE for head node..."
    
    # Install MUNGE packages
    dnf install -y munge munge-libs

    # Check if MUNGE key already exists and generate one if none exists
    info "Checking MUNGE key..."
    if [ ! -f /etc/munge/munge.key ]; then
        info "Generating MUNGE key..."
        set +u
        /usr/sbin/create-munge-key
        set -u
    else
        info "MUNGE key already exists; skipping generation"
    fi

    # chown munge:munge /etc/munge/munge.key
    # chmod 400 /etc/munge/munge.key
    
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
    dnf install -y slurm slurm-slurmctld slurm-devel
    
    info "SLURM controller installed successfully"
}

# Configure SLURM controller
configure_slurm() {
    info "Configuring SLURM controller..."

    : "${SLURM_UID:?SLURM_UID must be defined in components/slurm/slurm.conf}"
    : "${SLURM_GID:?SLURM_GID must be defined in components/slurm/slurm.conf}"

    # Ensure the controller and compute images use identical service IDs.
    local target_group target_user current_gid current_uid
    target_group="$(getent group "$SLURM_GID" | cut -d: -f1 || true)"

    if getent group slurm >/dev/null; then
        current_gid="$(getent group slurm | cut -d: -f3)"
        if [ "$current_gid" != "$SLURM_GID" ]; then
            if [ -n "$target_group" ] && [ "$target_group" != slurm ]; then
                error "GID $SLURM_GID is already used by group $target_group"
                return 1
            fi
            groupmod --gid "$SLURM_GID" slurm
        fi
    else
        if [ -n "$target_group" ]; then
            error "GID $SLURM_GID is already used by group $target_group"
            return 1
        fi
        groupadd --system --gid "$SLURM_GID" slurm
    fi

    target_user="$(getent passwd "$SLURM_UID" | cut -d: -f1 || true)"
    if id slurm >/dev/null 2>&1; then
        current_uid="$(id -u slurm)"
        if [ "$current_uid" != "$SLURM_UID" ]; then
            if [ -n "$target_user" ] && [ "$target_user" != slurm ]; then
                error "UID $SLURM_UID is already used by user $target_user"
                return 1
            fi
            usermod --uid "$SLURM_UID" slurm
        fi
        usermod --gid "$SLURM_GID" slurm
    else
        if [ -n "$target_user" ]; then
            error "UID $SLURM_UID is already used by user $target_user"
            return 1
        fi
        useradd --system \
            --uid "$SLURM_UID" \
            --gid "$SLURM_GID" \
            --home-dir /var/lib/slurm \
            --shell /sbin/nologin \
            slurm
    fi

    # Create SLURM directories
    mkdir -p /etc/slurm /var/log/slurm /var/spool/slurm/state /var/lib/slurm
    chown -R slurm:slurm /var/log/slurm /var/spool/slurm || true
    
    # Enable SLURM controller
    systemctl enable slurmctld || warn "slurmctld enable failed (may require config first)"
    systemctl start slurmctld || warn "slurmctld start failed (may require config first)"
    
    info "SLURM controller configuration completed"
    info "Running SLURM configuration file..."
    bash "$(dirname "$0")/configure.sh"
}

main() {
    info "Starting Rocky Linux head node SLURM setup..."

    configure_time_server
    
    # Install MUNGE first (SLURM prerequisite)
    install_munge
    
    # Install and configure SLURM controller
    install_slurm
    configure_slurm
    
    info "Head node SLURM setup completed successfully"
    info "Copy /etc/munge/munge.key to all compute nodes for authentication"
}

main "$@"
