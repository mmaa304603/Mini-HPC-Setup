#!/bin/bash

# Source common functions and configuration
source "$(dirname "$0")/../common/functions.sh"
source "$(dirname "$0")/../common/config.sh"

# Install Globus Connect Server
install_globus() {
    info "Installing Globus Connect Server..."
    
    # Add Globus repository
    cat > /etc/yum.repos.d/globus.repo << EOF
[globus]
name=Globus
baseurl=https://downloads.globus.org/toolkit/gt6/stable/rpm/el9/x86_64
enabled=1
gpgcheck=1
gpgkey=https://downloads.globus.org/toolkit/gt6/stable/rpm/el9/RPM-GPG-KEY-Globus
EOF
    
    # Install required packages
    local packages=(
        "globus-connect-server"
        "globus-connect-server-io"
        "globus-connect-server-id"
        "globus-connect-server-web"
        "globus-connect-server-manager"
    )
    
    for package in "${packages[@]}"; do
        install_package "$package"
    done
}

# Configure Globus Connect Server
configure_globus() {
    info "Configuring Globus Connect Server..."
    
    # Create Globus configuration
    cat > /etc/globus-connect-server.conf << EOF
[Globus Connect Server]
name = HPC Cluster
organization = Texas Tech University
contact_email = hpc-admin@ttu.edu
https_port = 443
http_port = 80
ip_address = 10.0.0.1
gridftp_port = 2811
gridftp_data_port_range = 50000-51000
gridftp_control_port_range = 50000-51000
gridftp_restrict_paths = /home,/scratch,/opt
gridftp_allow_anonymous = false
gridftp_require_encryption = true
gridftp_require_strong_authentication = true
gridftp_require_strong_encryption = true
gridftp_require_integrity = true
gridftp_require_mutual_authentication = true
gridftp_require_client_authentication = true
gridftp_require_server_authentication = true
gridftp_require_client_authorization = true
gridftp_require_server_authorization = true
gridftp_require_client_encryption = true
gridftp_require_server_encryption = true
gridftp_require_client_integrity = true
gridftp_require_server_integrity = true
gridftp_require_client_mutual_authentication = true
gridftp_require_server_mutual_authentication = true
EOF
    
    # Create storage gateway configuration
    cat > /etc/globus-connect-server/storage-gateway.conf << EOF
[Storage Gateway]
name = HPC Storage
type = POSIX
root = /home
path = /home
permissions = rw
anonymous = false
EOF
    
    # Create mapped collections
    cat > /etc/globus-connect-server/mapped-collections.conf << EOF
[Mapped Collections]
name = HPC Home Directories
type = mapped
storage_gateway = HPC Storage
path = /home
permissions = rw
anonymous = false
EOF
    
    # Enable and start services
    systemctl enable globus-connect-server
    systemctl enable globus-connect-server-io
    systemctl enable globus-connect-server-id
    systemctl enable globus-connect-server-web
    systemctl enable globus-connect-server-manager
    
    systemctl start globus-connect-server
    systemctl start globus-connect-server-io
    systemctl start globus-connect-server-id
    systemctl start globus-connect-server-web
    systemctl start globus-connect-server-manager
}

# Configure firewall
configure_firewall() {
    info "Configuring firewall for Globus..."
    
    # Allow Globus ports
    firewall-cmd --permanent --add-port=443/tcp
    firewall-cmd --permanent --add-port=80/tcp
    firewall-cmd --permanent --add-port=2811/tcp
    firewall-cmd --permanent --add-port=50000-51000/tcp
    
    # Reload firewall
    firewall-cmd --reload
}

# Main execution
main() {
    check_root
    
    install_globus
    configure_globus
    configure_firewall
    
    info "Globus Connect Server setup completed successfully"
}

main "$@" 