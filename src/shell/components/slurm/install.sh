#!/bin/bash

# Source common functions and configuration
source "$(dirname "$0")/../common/functions.sh"
source "$(dirname "$0")/../common/config.sh"

# Install SLURM
install_slurm() {
    info "Installing SLURM..."
    
    # Install EPEL repository
    dnf install -y epel-release
    
    # Install SLURM packages
    dnf install -y slurm slurm-devel
    
    info "SLURM installed successfully"
}

# Configure SLURM
configure_slurm() {
    info "Configuring SLURM..."
    
    # Create SLURM configuration
    cat > /etc/slurm/slurm.conf << EOF
ClusterName=$CLUSTER_NAME

# Node definitions
NodeName=$NODE_PREFIX[1-$NODE_COUNT] State=UNKNOWN
PartitionName=$PARTITION_NAME Nodes=$NODE_PREFIX[1-$NODE_COUNT] Default=$DEFAULT_PARTITION MaxTime=$MAX_TIME State=UP

# Prolog/Epilog
Prolog=/etc/slurm/prolog.sh
Epilog=/etc/slurm/epilog.sh

# Logging
SlurmctldLogFile=$LOG_DIR/slurmctld.log
SlurmdLogFile=$LOG_DIR/slurmd.log

# Authentication
AuthAltTypes=auth/munge
AuthAltParameters=/var/run/munge/munge.socket.2

# State Save
StateSaveLocation=$STATE_SAVE_LOCATION

# Accounting
AccountingStorageType=$ACCOUNTING_STORAGE_TYPE
AccountingStorageHost=$ACCOUNTING_STORAGE_HOST
AccountingStorageUser=$ACCOUNTING_STORAGE_USER
AccountingStoragePass=/var/run/munge/munge.socket.2

# Job submission
MaxJobCount=$MAX_JOB_COUNT
MaxJobsPerUser=$MAX_JOBS_PER_USER

# Scheduling
SelectType=$SELECT_TYPE
FastSchedule=$FAST_SCHEDULE
EOF
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    chown slurm:slurm "$LOG_DIR"
    
    # Start and enable services
    systemctl enable --now slurmctld
    systemctl enable --now slurmd
    
    info "SLURM configured successfully"
}

# Main execution
main() {
    check_root
    
    install_slurm
    configure_slurm
    
    info "SLURM installation and configuration completed successfully"
}

main "$@" 