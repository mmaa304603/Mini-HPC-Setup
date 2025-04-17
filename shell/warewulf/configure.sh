#!/bin/bash

# Source common functions
source "$(dirname "$0")/../common/functions.sh"

# Check if running as root
check_root

# Configure Warewulf
configure_warewulf() {
    info "Configuring Warewulf..."
    
    # Backup existing configuration
    backup_file "/etc/warewulf/warewulf.conf"
    
    # Create new configuration
    cat > "/etc/warewulf/warewulf.conf" << EOF
[warewulf]
ipaddr = $HEAD_NODE_IP
netmask = $NETWORK_MASK
network = $NETWORK
port = $WAREWULF_PORT
dhcp_start = $DHCP_START
dhcp_end = $DHCP_END
tftp_server = $HEAD_NODE_IP
container_base = $CONTAINER_BASE
container_name = $CONTAINER_NAME
EOF

    # Restart Warewulf service
    systemctl restart warewulfd || {
        error "Failed to restart Warewulf service"
        return 1
    }
}

# Create and import Rocky Linux container
setup_container() {
    info "Setting up Rocky Linux container..."
    
    # Create container
    wwctl container build "$CONTAINER_NAME" || {
        error "Failed to build container"
        return 1
    }
    
    # Import container
    wwctl container import "$CONTAINER_NAME" || {
        error "Failed to import container"
        return 1
    }
}

# Configure compute nodes
configure_compute_nodes() {
    info "Configuring compute nodes..."
    
    for i in "${!COMPUTE_NODES[@]}"; do
        local node="${COMPUTE_NODES[$i]}"
        local ip="${COMPUTE_NODE_IPS[$i]}"
        
        info "Configuring node $node ($ip)..."
        
        # Add node to Warewulf
        wwctl node add "$node" --ipaddr "$ip" || {
            error "Failed to add node $node"
            continue
        }
        
        # Set node profile
        wwctl node set "$node" --profile default || {
            error "Failed to set profile for node $node"
            continue
        }
        
        # Configure node
        wwctl node configure "$node" || {
            error "Failed to configure node $node"
            continue
        }
    done
}

# Main execution
main() {
    ensure_dir "$LOG_DIR"
    
    # Configure Warewulf
    configure_warewulf
    
    # Setup container
    setup_container
    
    # Configure compute nodes
    configure_compute_nodes
    
    info "Warewulf configuration completed successfully"
}

main "$@" 