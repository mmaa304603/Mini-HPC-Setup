#!/bin/bash
set -e

# Source common functions and configuration
source "$(dirname "$0")/../../lib/functions.sh" || exit 1
source "$(dirname "$0")/../../lib/config.sh" || exit 1  

# Load network configuration for IP-related values
load_component_config "network"
export_config

# Warewulf version for RPM installation
WAREWULF_VERSION="4.6.4"
WAREWULF_CONNECTION_NAME="${WAREWULF_CONNECTION_NAME:-cluster-internal}"

# Install Warewulf
install_warewulf() {
    info "Installing Warewulf v${WAREWULF_VERSION}..."
    
    # Install Warewulf RPM from official GitHub releases
    local rpm_url="https://github.com/warewulf/warewulf/releases/download/v${WAREWULF_VERSION}/warewulf-${WAREWULF_VERSION}-1.el9.x86_64.rpm"
    
    info "Downloading and installing Warewulf RPM from: $rpm_url"
    dnf install -y "$rpm_url" || {
        error "Failed to install Warewulf RPM"
        return 1
    }
    
    info "Warewulf installation completed successfully"
}

configure_head_node() {
    : "${HEAD_NODE_HOSTNAME:?HEAD_NODE_HOSTNAME must be set in components/network/network.conf}"
    local head_ip="${HEAD_NODE_IP:-${NETWORK_IP:-}}"
    local head_interface="${HEAD_NETWORK_INTERFACE:-${NETWORK_INTERFACE:-}}"
    local prefix="${CLUSTER_NETWORK_CIDR#*/}"

    : "${head_ip:?HEAD_NODE_IP or NETWORK_IP must be set}"
    : "${head_interface:?HEAD_NETWORK_INTERFACE or NETWORK_INTERFACE must be set}"
    : "${CLUSTER_NETWORK_CIDR:?CLUSTER_NETWORK_CIDR must be set in components/network/network.conf}"

    info "Configuring head node as ${HEAD_NODE_HOSTNAME} on ${head_interface} (${head_ip})"

    hostnamectl set-hostname "$HEAD_NODE_HOSTNAME"

    if grep -q "^${head_ip}[[:space:]]" /etc/hosts; then
        sed -i "s/^${head_ip}[[:space:]].*/${head_ip} ${HEAD_NODE_HOSTNAME} ${HEAD_NODE_HOSTNAME}.localdomain/" /etc/hosts
    else
        echo "${head_ip} ${HEAD_NODE_HOSTNAME} ${HEAD_NODE_HOSTNAME}.localdomain" >> /etc/hosts
    fi

    nmcli connection delete "$WAREWULF_CONNECTION_NAME" 2>/dev/null || true
    nmcli connection add type ethernet ifname "$head_interface" con-name "$WAREWULF_CONNECTION_NAME" \
        ipv4.method manual ipv4.addresses "${head_ip}/${prefix}" ipv4.never-default yes connection.autoconnect yes
    nmcli connection up "$WAREWULF_CONNECTION_NAME"
}

# Configure firewall
configure_firewall() {
    info "Configuring firewalld for Warewulf..."
    
    # Restart firewalld to register the added service file
    systemctl restart firewalld
    
    # Add services to firewall (following official docs)
    firewall-cmd --permanent --add-service=warewulf
    firewall-cmd --permanent --add-service=dhcp
    firewall-cmd --permanent --add-service=nfs
    firewall-cmd --permanent --add-service=tftp
    
    # Reload firewall
    firewall-cmd --reload
    
    info "Firewall configuration completed"
}

# Configure Warewulf
configure_warewulf() {
    info "Configuring Warewulf..."
    
    # Copy component configuration to system location
    cp "$(dirname "$0")/warewulf.conf" /etc/warewulf/warewulf.conf
    
    # Update configuration with network-specific values
    sed -i "s/ipaddr: 10.0.0.1/ipaddr: ${HEAD_NODE_IP}/" /etc/warewulf/warewulf.conf
    sed -i "s/netmask: 255.255.252.0/netmask: ${NETWORK_MASK}/" /etc/warewulf/warewulf.conf
    sed -i "s/network: 10.0.0.0/network: ${NETWORK}/" /etc/warewulf/warewulf.conf
    sed -i "s/range start: 10.0.1.1/range start: ${DHCP_START}/" /etc/warewulf/warewulf.conf
    sed -i "s/range end: 10.0.1.255/range end: ${DHCP_END}/" /etc/warewulf/warewulf.conf
    
    info "Warewulf configuration file created from component template"
}


# Configure system services automatically
configure_system_services() {
    info "Configuring system services automatically..."
    
    # Enable and start the Warewulf service
    systemctl enable --now warewulfd || {
        error "Failed to enable/start warewulfd service"
        return 1
    }
    
    # Configure all required services with wwctl
    info "Running wwctl configure --all"
    wwctl configure --all || {
        error "Failed to configure system services with wwctl"
        return 1
    }
    
    # Fix SELinux labels if needed
    if command_exists restorecon; then
        info "Fixing SELinux labels for tftpboot"
        restorecon -Rv /var/lib/tftpboot/ || {
            warn "Failed to fix SELinux labels (may not be needed)"
        }
    fi
    
    info "System services configuration completed"
}


# Main execution
main() {
    check_root
    
    # Install Warewulf
    install_warewulf

    # Configure hostname and internal cluster interface before generating services.
    configure_head_node
    
    # Configure firewalld first (as per official docs)
    configure_firewall
    
    # Configure Warewulf
    configure_warewulf
    
    # Configure system services automatically
    configure_system_services
    
    info "Warewulf installation completed successfully"

    # Run configuration
    source "$(dirname "$0")/configure.sh"

    sudo wwctl overlay build
    info "Now boot your compute nodes!"
}

main "$@" 
