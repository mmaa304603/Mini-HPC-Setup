#!/bin/bash

# Source common functions and configuration
source "$(dirname "$0")/../common/functions.sh"
source "$(dirname "$0")/../common/config.sh"

# Install Warewulf
install_warewulf() {
    info "Installing Warewulf..."
    
    # Add Warewulf repository
    cat > /etc/yum.repos.d/warewulf.repo << EOF
[warewulf]
name=Warewulf
baseurl=https://warewulf.org/releases/el/9/x86_64
enabled=1
gpgcheck=0
EOF
    
    # Install Warewulf packages
    local packages=(
        "warewulf4"
        "warewulf4-client"
        "warewulf4-common"
        "warewulf4-provision"
        "warewulf4-vnfs"
        "warewulf4-ipmi"
        "warewulf4-overlay"
        "warewulf4-warewulfd"
    )
    
    for package in "${packages[@]}"; do
        install_package "$package"
    done
}

# Configure Warewulf
configure_warewulf() {
    info "Configuring Warewulf..."
    
    # Create Warewulf configuration
    cat > /etc/warewulf/warewulf.conf << EOF
WW_INTERNAL: 43
ipaddr: 10.0.0.1
netmask: 255.255.252.0
network: 10.0.0.0
warewulf:
  port: 9873
  secure: false
  update interval: 60
  autobuild: true
  host overlay: true
  syslog: true
dhcp:
  enabled: true
  range start: 10.0.1.1
  range end: 10.0.1.255
  systemd name: dhcpd
tftp:
  enabled: true
  tftpdir: /var/lib/tftpboot
  systemd name: tftp
nfs:
  enabled: true
  export paths:
    - path: /home
      export options: rw,sync,no_subtree_check
    - path: /opt
      export options: rw,sync,no_subtree_check
    - path: /scratch
      export options: rw,sync,no_subtree_check
  systemd name: nfs-server
EOF
    
    # Create node configuration
    cat > /etc/warewulf/nodes.conf << EOF
nodes:
  - name: compute-01
    ipaddr: 10.0.1.1
    hwaddr: 00:00:00:00:00:01
    type: compute
  - name: compute-02
    ipaddr: 10.0.1.2
    hwaddr: 00:00:00:00:00:02
    type: compute
  - name: compute-03
    ipaddr: 10.0.1.3
    hwaddr: 00:00:00:00:00:03
    type: compute
  - name: gpu-01
    ipaddr: 10.0.1.4
    hwaddr: 00:00:00:00:00:04
    type: gpu
EOF
    
    # Create VNFS configuration
    cat > /etc/warewulf/vnfs.conf << EOF
vnfs:
  - name: rocky9
    path: /var/lib/warewulf/vnfs/rocky9
    kernel: /boot/vmlinuz-$(uname -r)
    initramfs: /boot/initramfs-$(uname -r).img
    overlay:
      - /etc/warewulf/overlays/rocky9
EOF
    
    # Create overlay directory
    mkdir -p /etc/warewulf/overlays/rocky9
    
    # Enable and start services
    systemctl enable warewulfd
    systemctl enable dhcpd
    systemctl enable tftp
    systemctl enable nfs-server
    
    systemctl start warewulfd
    systemctl start dhcpd
    systemctl start tftp
    systemctl start nfs-server
}

# Create VNFS image
create_vnfs() {
    info "Creating VNFS image..."
    
    # Create VNFS directory
    mkdir -p /var/lib/warewulf/vnfs/rocky9
    
    # Create base image
    wwctl vnfs create rocky9 --root /var/lib/warewulf/vnfs/rocky9
    
    # Add required packages
    wwctl vnfs add-packages rocky9 \
        --packages "base-minimal openssh-server openssh-clients nfs-utils slurm slurm-slurmd"
    
    # Build VNFS
    wwctl vnfs build rocky9
}

# Configure firewall
configure_firewall() {
    info "Configuring firewall for Warewulf..."
    
    # Allow Warewulf port
    firewall-cmd --permanent --add-port=9873/tcp
    
    # Allow DHCP
    firewall-cmd --permanent --add-service=dhcp
    
    # Allow TFTP
    firewall-cmd --permanent --add-service=tftp
    
    # Allow NFS
    firewall-cmd --permanent --add-service=nfs
    firewall-cmd --permanent --add-service=mountd
    firewall-cmd --permanent --add-service=rpc-bind
    
    # Reload firewall
    firewall-cmd --reload
}

# Main execution
main() {
    check_root
    
    install_warewulf
    configure_warewulf
    create_vnfs
    configure_firewall
    
    info "Warewulf setup completed successfully"
}

main "$@" 