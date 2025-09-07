#!/bin/bash

# Source common functions and configuration
source "$(dirname "$0")/../../lib/functions.sh"
source "$(dirname "$0")/../../lib/config.sh"

# Load network configuration for IP-related values
load_config "network.conf"
export_config

# Warewulf version for RPM installation
WAREWULF_VERSION="4.6.4"

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

# Configure Warewulf
configure_warewulf() {
    info "Configuring Warewulf..."
    
    # Create Warewulf configuration (following official docs format)
    cat > /etc/warewulf/warewulf.conf << EOF
ipaddr: ${HEAD_NODE_IP}
netmask: ${NETWORK_MASK}
network: ${NETWORK}
warewulf:
  port: 9873
  secure: false
  update interval: 60
  autobuild overlays: true
  host overlay: true
  datastore: /usr/share
  grubboot: false
dhcp:
  enabled: true
  template: default
  range start: ${DHCP_START}
  range end: ${DHCP_END}
  systemd name: dhcpd
tftp:
  enabled: true
  tftproot: /var/lib/tftpboot
  systemd name: tftp
  ipxe:
    "00:00": undionly.kpxe
    "00:07": ipxe-snponly-x86_64.efi
    "00:09": ipxe-snponly-x86_64.efi
    00:0B: arm64-efi/snponly.efi
nfs:
  enabled: true
  export paths:
  - path: /home
    export options: rw,sync
  - path: /opt
    export options: ro,sync,no_root_squash
  systemd name: nfs-server
image mounts:
- source: /etc/resolv.conf
  dest: /etc/resolv.conf
  readonly: true
paths:
  bindir: /usr/bin
  sysconfdir: /etc
  localstatedir: /var/lib
  ipxesource: /usr/share/ipxe
  srvdir: /var/lib
  firewallddir: /usr/lib/firewalld/services
  systemddir: /usr/lib/systemd/system
  wwoverlaydir: /var/lib/warewulf/overlays
  wwchrootdir: /var/lib/warewulf/chroots
  wwprovisiondir: /var/lib/warewulf/provision
  wwclientdir: /warewulf
EOF
    
    info "Warewulf configuration file created successfully"
}

# Create VNFS image
create_vnfs() {
    info "Creating VNFS image using official Docker image..."
    
    # Import base node image from Docker Hub (following official docs)
    info "Importing base node image: rockylinux-9"
    wwctl image import "docker://ghcr.io/warewulf/warewulf-rockylinux:9" "rockylinux-9" --build || {
        error "Failed to import base node image"
        return 1
    }
    
    # Set the image for the default node profile
    info "Setting default node profile to use image: rockylinux-9"
    wwctl profile set "default" --image "rockylinux-9" || {
        error "Failed to set default node profile"
        return 1
    }
    
    info "VNFS image creation completed successfully"
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

# Main execution
main() {
    check_root
    
    # Install Warewulf
    install_warewulf
    
    # Configure firewalld first (as per official docs)
    configure_firewall
    
    # Configure Warewulf
    configure_warewulf
    
    # Configure system services automatically
    configure_system_services
    
    # Create VNFS image
    create_vnfs
    
    info "Warewulf setup completed successfully"
    info "Next steps:"
    info "1. Configure default node profile: wwctl profile set -y default --netmask=${NETWORK_MASK} --gateway=${HEAD_NODE_IP}"
    info "2. Add nodes: wwctl node add <nodename> --ipaddr=<ip> --discoverable=true"
    info "3. Build overlays: wwctl overlay build"
    info "4. Boot your compute nodes!"
}

main "$@" 