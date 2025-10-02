#!/bin/bash

# Distribute MUNGE key to compute nodes
# Usage: ./distribute-munge-key.sh <node1> <node2> ...

# Source common functions
source "$(dirname "$0")/../../lib/functions.sh"

check_root

# MUNGE key file
MUNGE_KEY="/etc/munge/munge.key"

# Check if MUNGE key exists
if [ ! -f "$MUNGE_KEY" ]; then
    error "MUNGE key not found at $MUNGE_KEY"
    error "Run the SLURM install script first to generate the key"
    exit 1
fi

# Function to distribute key to a single node
distribute_to_node() {
    local node="$1"
    info "Distributing MUNGE key to $node..."
    
    # Copy key to node
    scp "$MUNGE_KEY" "root@$node:/etc/munge/munge.key" || {
        error "Failed to copy MUNGE key to $node"
        return 1
    }
    
    # Set ownership and permissions on remote node
    ssh "root@$node" "chown munge: /etc/munge/munge.key && chmod 0400 /etc/munge/munge.key" || {
        error "Failed to set permissions on $node"
        return 1
    }
    
    # Start MUNGE service on remote node
    ssh "root@$node" "systemctl enable munge && systemctl start munge" || {
        warn "Failed to start MUNGE service on $node"
    }
    
    info "MUNGE key distributed to $node successfully"
}

# Main execution
main() {
    if [ $# -eq 0 ]; then
        error "Usage: $0 <node1> <node2> ..."
        error "Example: $0 compute-01 compute-02 gpu-01"
        exit 1
    fi
    
    info "Distributing MUNGE key to compute nodes..."
    
    for node in "$@"; do
        distribute_to_node "$node"
    done
    
    info "MUNGE key distribution completed"
    info "Test authentication with: munge -n | ssh <node> unmunge"
}

main "$@"
