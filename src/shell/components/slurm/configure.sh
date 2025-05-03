#!/bin/bash

# Source common functions
source "$(dirname "$0")/../common/functions.sh"

# Check if running as root
check_root

# Configure SLURM
configure_slurm() {
    info "Configuring SLURM..."
    
    # Backup existing configuration
    backup_file "/etc/slurm/slurm.conf"
    
    # Create new configuration
    cat > "/etc/slurm/slurm.conf" << EOF
ClusterName=$SLURM_CLUSTER_NAME

# Node definitions
$(for node in "${COMPUTE_NODES[@]}"; do
    echo "NodeName=$node State=UNKNOWN"
done)

# Partition definitions
PartitionName=$SLURM_PARTITION_NAME Nodes=$(IFS=,; echo "${COMPUTE_NODES[*]}") Default=YES MaxTime=INFINITE State=UP

# Prolog and Epilog
Prolog=/etc/slurm/prolog.sh
Epilog=/etc/slurm/epilog.sh

# Logging
SlurmctldLogFile=/var/log/slurm/slurmctld.log
SlurmdLogFile=/var/log/slurm/slurmd.log

# Authentication
AuthAltTypes=auth/munge
AuthAltParameters=/var/run/munge/munge.socket.2

# Task control
TaskPlugin=task/affinity
TaskPlugin=task/cgroup

# Node configuration
$(for node in "${COMPUTE_NODES[@]}"; do
    echo "NodeName=$node Sockets=$SLURM_SOCKETS CoresPerSocket=$SLURM_CORES_PER_SOCKET ThreadsPerCore=$SLURM_THREADS_PER_CORE State=UNKNOWN"
done)

# Default settings
DefMemPerNode=$SLURM_DEFAULT_MEM
MaxMemPerNode=$SLURM_MAX_MEM
EOF

    # Create prolog and epilog scripts
    create_prolog_epilog
}

# Create prolog and epilog scripts
create_prolog_epilog() {
    info "Creating prolog and epilog scripts..."
    
    # Create prolog script
    cat > "/etc/slurm/prolog.sh" << 'EOF'
#!/bin/bash
# Prolog script for SLURM jobs
exit 0
EOF
    chmod +x "/etc/slurm/prolog.sh"
    
    # Create epilog script
    cat > "/etc/slurm/epilog.sh" << 'EOF'
#!/bin/bash
# Epilog script for SLURM jobs
exit 0
EOF
    chmod +x "/etc/slurm/epilog.sh"
}

# Configure Munge on compute nodes
configure_munge_compute_nodes() {
    info "Configuring Munge on compute nodes..."
    
    # Copy Munge key to compute nodes
    for node in "${COMPUTE_NODES[@]}"; do
        info "Configuring Munge on node $node..."
        
        # Create Munge directory on compute node
        remote_exec "$node" "mkdir -p /etc/munge"
        
        # Copy Munge key
        scp /etc/munge/munge.key "root@$node:/etc/munge/munge.key"
        
        # Set permissions and start Munge
        remote_exec "$node" "chmod 400 /etc/munge/munge.key && systemctl enable --now munge"
    done
}

# Start SLURM services
start_slurm_services() {
    info "Starting SLURM services..."
    
    if [[ "$HOSTNAME" == "$HEAD_NODE" ]]; then
        # Start slurmctld on head node
        start_service "slurmctld"
    fi
    
    # Start slurmd on all nodes
    start_service "slurmd"
}

# Main execution
main() {
    ensure_dir "$LOG_DIR"
    
    # Configure SLURM
    configure_slurm
    
    # Configure Munge on compute nodes
    configure_munge_compute_nodes
    
    # Start services
    start_slurm_services
    
    info "SLURM configuration completed successfully"
}

main "$@" 