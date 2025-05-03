#!/bin/bash

# Source common functions and configuration
source "$(dirname "$0")/../common/functions.sh"
source "$(dirname "$0")/../common/config.sh"

# Configure network interface
configure_network() {
    info "Configuring network interface $NETWORK_INTERFACE..."
    
    # Create network configuration file
    cat > "/etc/sysconfig/network-scripts/ifcfg-$NETWORK_INTERFACE" << EOF
DEVICE=$NETWORK_INTERFACE
BOOTPROTO=static
IPADDR=$HEAD_NODE_IP
NETMASK=$NETWORK_MASK
ONBOOT=yes
TYPE=Ethernet
EOF
    
    # Restart network service
    systemctl restart network
    
    info "Network interface configured successfully"
}

# Configure firewall
configure_firewall() {
    if [ "$FIREWALL_ENABLED" != "true" ]; then
        info "Firewall configuration is disabled"
        return 0
    fi
    
    info "Configuring firewall..."
    
    # Allow required services
    for service in "${FIREWALL_SERVICES[@]}"; do
        info "Adding service to firewall: $service"
        firewall-cmd --permanent --add-service="$service"
    done
    
    # Allow required ports
    for port in "${FIREWALL_PORTS[@]}"; do
        info "Adding port to firewall: $port"
        firewall-cmd --permanent --add-port="$port/tcp"
    done
    
    # Reload firewall
    firewall-cmd --reload
    
    info "Firewall configured successfully"
}

# Main execution
main() {
    check_root
    
    configure_network
    configure_firewall
    
    info "Network configuration completed successfully"
}

main "$@" 