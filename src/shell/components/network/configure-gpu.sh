#!/bin/bash

# Source common functions and configuration
source "$(dirname "$0")/../../lib/functions.sh"
source "$(dirname "$0")/../../lib/config.sh"

# Load network configuration
load_component_config "network"

# GPU Node Network Configuration
# This script configures the network for the GPU compute node (Jetson Orin Nano)
# IP: 10.0.2.4 (static assignment, not managed by Warewulf)

# GPU Node configuration loaded from network.conf
# Variables: GPU_NODE_IP, GPU_NETWORK_INTERFACE, HEAD_NODE_IP

# Configure GPU node network interface
configure_gpu_network() {
    info "Configuring GPU node network interface $GPU_NETWORK_INTERFACE..."
    
    # Remove any existing connection for this interface
    nmcli con delete "$GPU_NETWORK_INTERFACE" 2>/dev/null || true
    
    # Create NetworkManager connection for GPU node
    nmcli con add type ethernet ifname "$GPU_NETWORK_INTERFACE" con-name gpu \
      ip4 "$GPU_NODE_IP/22" \
      gw4 "$HEAD_NODE_IP" \
      connection.autoconnect yes
    
    # Activate the connection
    nmcli con up gpu
    
    info "GPU node network interface configured successfully"
}

# Configure DNS for GPU node
configure_gpu_dns() {
    info "Configuring DNS for GPU node..."
    
    # Set DNS servers
    nmcli con mod gpu ipv4.dns "8.8.8.8,8.8.4.4"
    
    # Set search domain
    nmcli con mod gpu ipv4.dns-search "hpc.ttu.edu"
    
    info "DNS configuration completed"
}

# Test network connectivity
test_network() {
    info "Testing network connectivity..."
    
    # Test connectivity to head node
    if ping -c 3 "$HEAD_NODE_IP" >/dev/null 2>&1; then
        info "✓ Connectivity to head node ($HEAD_NODE_IP) successful"
    else
        error "✗ Cannot reach head node ($HEAD_NODE_IP)"
        return 1
    fi
    
    # Test external connectivity
    if ping -c 3 "8.8.8.8" >/dev/null 2>&1; then
        info "✓ External connectivity successful"
    else
        warn "⚠ External connectivity failed (may be expected if head node routing not configured)"
    fi
    
    info "Network connectivity test completed"
}

# Main execution
main() {
    check_root
    
    info "Starting GPU node network configuration..."
    info "Target IP: $GPU_NODE_IP"
    info "Gateway: $HEAD_NODE_IP"
    
    configure_gpu_network
    configure_gpu_dns
    test_network
    
    info "GPU node network configuration completed successfully"
}

main "$@"
