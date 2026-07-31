#!/bin/bash

# Source common functions and configuration
source "$(dirname "$0")/../../lib/functions.sh"
source "$(dirname "$0")/../../lib/config.sh"

# Load network configuration
load_component_config "network"

# Configure network interface using NetworkManager (HEAD NODE)
configure_network() {
    info "Configuring HEAD NODE network interface $HEAD_NETWORK_INTERFACE using NetworkManager..."
    
    # Remove any existing connection for this interface
    nmcli con delete "$HEAD_NETWORK_INTERFACE" 2>/dev/null || true
    
    # Create NetworkManager connection
    nmcli con add type ethernet ifname "$HEAD_NETWORK_INTERFACE" con-name cluster-internal \
      ip4 "$HEAD_NODE_IP/22" \
      connection.autoconnect yes
    
    # Activate the connection
    nmcli con up cluster-internal
    
    info "Network interface configured successfully using NetworkManager"
}

# Configure IP forwarding and masquerading
configure_routing() {
    info "Configuring IP forwarding and masquerading for cluster gateway..."
    
    # Enable IP forwarding permanently
    if ! grep -q "net.ipv4.ip_forward=1" /etc/sysctl.conf; then
        echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
        info "Added IP forwarding to /etc/sysctl.conf"
    else
        info "IP forwarding already configured in /etc/sysctl.conf"
    fi
    
    # Apply IP forwarding immediately
    sysctl -p >/dev/null 2>&1 || true
    echo 1 > /proc/sys/net/ipv4/ip_forward
    info "IP forwarding enabled"
    
    # Configure firewall zones and masquerading
    EXTERNAL_IF="enp0s21f0u6c2"   # Internet-facing NIC
    # EXTERNAL_IF="enp0s3"   # Internet-facing NIC - Change network interface due to hardware constraints while testing
    
    INTERNAL_IF="enp2s0"           # Cluster-facing NIC
    # INTERNAL_IF="enp0s8"           # Cluster-facing NIC - Change network interface due to hardware constraints while testing
    
    # Set up firewall zones
    firewall-cmd --permanent --zone=public --add-interface="$EXTERNAL_IF"
    firewall-cmd --permanent --zone=internal --add-interface="$INTERNAL_IF"
    info "Firewall zones configured: public=$EXTERNAL_IF, internal=$INTERNAL_IF"
    
    # Configure masquerading for internal traffic out external interface
    firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -o "$EXTERNAL_IF" -j MASQUERADE
    firewall-cmd --reload
    info "Firewall masquerading configured for internal traffic"
    
    info "Routing configuration completed successfully"
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
    configure_routing
    configure_firewall
    
    info "Network configuration completed successfully"
}

main "$@"
