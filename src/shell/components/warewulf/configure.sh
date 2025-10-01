#!/bin/bash

# Source common functions and configuration
source "$(dirname "$0")/../../lib/functions.sh"
source "$(dirname "$0")/../../lib/config.sh"

# Load network configuration for IP-related values
load_component_config "network"
export_config

# Update Warewulf configuration (post-installation)
update_warewulf_config() {
    info "Updating Warewulf configuration..."
    
    # Backup existing configuration
    if [ -f "/etc/warewulf/warewulf.conf" ]; then
        cp "/etc/warewulf/warewulf.conf" "/etc/warewulf/warewulf.conf.backup.$(date +%Y%m%d_%H%M%S)"
        info "Backed up existing configuration"
    fi
    
    # Update configuration with network-specific values
    sed -i "s/ipaddr: 10.0.0.1/ipaddr: ${HEAD_NODE_IP}/" /etc/warewulf/warewulf.conf
    sed -i "s/netmask: 255.255.252.0/netmask: ${NETWORK_MASK}/" /etc/warewulf/warewulf.conf
    sed -i "s/network: 10.0.0.0/network: ${NETWORK}/" /etc/warewulf/warewulf.conf
    sed -i "s/range start: 10.0.1.1/range start: ${DHCP_START}/" /etc/warewulf/warewulf.conf
    sed -i "s/range end: 10.0.1.255/range end: ${DHCP_END}/" /etc/warewulf/warewulf.conf
    
    # Restart Warewulf service
    systemctl restart warewulfd || {
        error "Failed to restart Warewulf service"
        return 1
    }
    
    info "Warewulf configuration updated successfully"
}

# Update VNFS image (post-installation)
update_vnfs() {
    info "Updating VNFS image..."
    
    # Check if image exists, if not create it
    if ! wwctl image list | grep -q "rockylinux-9.6"; then
        info "VNFS image not found, creating new image..."
        wwctl image import "docker://ghcr.io/warewulf/warewulf-rockylinux:9.6" "rockylinux-9.6" --build || {
            error "Failed to import base node image"
            return 1
        }
    else
        info "VNFS image already exists, updating..."
        wwctl image build "rockylinux-9.6" || {
            error "Failed to rebuild VNFS image"
            return 1
        }
    fi
    
    info "VNFS image update completed"
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
    check_root
    
    # Update Warewulf configuration
    update_warewulf_config
    
    # Update VNFS image
    update_vnfs
    
    # Configure compute nodes
    configure_compute_nodes
    
    info "Warewulf configuration completed successfully"
    info "Next steps:"
    info "1. Add nodes: wwctl node add <nodename> --ipaddr=<ip> --discoverable=true"
    info "2. Build overlays: wwctl overlay build"
    info "3. Boot your compute nodes!"
}

main "$@" 