#!/bin/bash

# Source common functions
source "$(dirname "$0")/../common/functions.sh"

# Check if running as root
check_root

# Configure network interface
configure_network() {
    local interface=$1
    local ip=$2
    local netmask=$3

    info "Configuring network interface $interface..."
    
    # Backup existing network configuration
    backup_file "/etc/sysconfig/network-scripts/ifcfg-$interface"
    
    # Create new network configuration
    cat > "/etc/sysconfig/network-scripts/ifcfg-$interface" << EOF
DEVICE=$interface
BOOTPROTO=static
IPADDR=$ip
NETMASK=$netmask
ONBOOT=yes
TYPE=Ethernet
EOF

    # Restart network service
    systemctl restart network || {
        error "Failed to restart network service"
        return 1
    }
}

# Configure DHCP server
configure_dhcp() {
    info "Configuring DHCP server..."
    
    # Install DHCP server
    install_package "dhcp-server"
    
    # Backup existing DHCP configuration
    backup_file "/etc/dhcp/dhcpd.conf"
    
    # Create new DHCP configuration
    cat > "/etc/dhcp/dhcpd.conf" << EOF
default-lease-time 600;
max-lease-time 7200;

subnet $NETWORK netmask $NETWORK_MASK {
    range $DHCP_START $DHCP_END;
    option routers $HEAD_NODE_IP;
    option domain-name-servers $HEAD_NODE_IP;
    option domain-name "$SLURM_CLUSTER_NAME";
}
EOF

    # Start and enable DHCP service
    start_service "dhcpd"
}

# Configure TFTP server
configure_tftp() {
    info "Configuring TFTP server..."
    
    # Install TFTP server
    install_package "tftp-server"
    
    # Configure firewall for TFTP
    configure_firewall "69" "tftp"
    
    # Start and enable TFTP service
    start_service "tftp"
}

# Main execution
main() {
    ensure_dir "$LOG_DIR"
    
    # Configure head node network
    configure_network "$NETWORK_INTERFACE" "$HEAD_NODE_IP" "$NETWORK_MASK"
    
    # Configure DHCP and TFTP servers
    configure_dhcp
    configure_tftp
    
    info "Network configuration completed successfully"
}

main "$@" 