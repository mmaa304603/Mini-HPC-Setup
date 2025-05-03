#!/bin/bash

# Source common functions
source "$(dirname "$0")/../common/functions.sh"

# Check if running as root
check_root

# Configuration
SQUID_VERSION="5.9"
SQUID_CONFIG_DIR="/etc/squid"
SQUID_CACHE_DIR="/var/spool/squid"
SQUID_LOG_DIR="/var/log/squid"
SQUID_USER="squid"
SQUID_GROUP="squid"
SQUID_PORT="3128"
SQUID_MEMORY_CACHE="256 MB"
SQUID_DISK_CACHE="10000 MB"
SQUID_MAX_OBJECT_SIZE="4096 KB"
SQUID_MAX_OBJECT_SIZE_IN_MEMORY="512 KB"
SQUID_CACHE_DIR_LEVELS="2"
SQUID_CACHE_DIR_L1="16"
SQUID_CACHE_DIR_L2="256"

# Install dependencies
install_dependencies() {
    info "Installing Squid dependencies..."
    
    # Required packages
    local packages=(
        "wget"
        "gcc"
        "gcc-c++"
        "make"
        "pcre-devel"
        "openssl-devel"
        "libcap-devel"
        "libtool"
        "autoconf"
        "automake"
        "libxml2-devel"
        "libcap"
        "libcap-devel"
        "libcap-ng-devel"
        "libselinux-devel"
        "pcre-devel"
        "libtool-ltdl-devel"
    )
    
    for package in "${packages[@]}"; do
        install_package "$package"
    done
}

# Download and install Squid
install_squid() {
    info "Installing Squid ${SQUID_VERSION}..."
    
    # Download source
    cd /tmp
    wget http://www.squid-cache.org/Versions/v5/squid-${SQUID_VERSION}.tar.gz
    tar -xzf squid-${SQUID_VERSION}.tar.gz
    cd squid-${SQUID_VERSION}
    
    # Configure
    ./configure --prefix=/usr \
                --sysconfdir=${SQUID_CONFIG_DIR} \
                --localstatedir=/var \
                --libexecdir=/usr/lib64/squid \
                --datadir=/usr/share/squid \
                --with-logdir=${SQUID_LOG_DIR} \
                --with-pidfile=/var/run/squid.pid \
                --with-default-user=${SQUID_USER} \
                --with-openssl \
                --enable-ssl \
                --enable-ssl-crtd \
                --enable-linux-netfilter \
                --enable-linux-tproxy \
                --enable-http-violations \
                --enable-icap-client \
                --enable-esi \
                --enable-ecap \
                --enable-auth-basic \
                --enable-auth-digest \
                --enable-auth-negotiate \
                --enable-auth-ntlm \
                --enable-external-acl-helpers \
                --enable-url-rewrite-helpers \
                --enable-disk-io \
                --enable-removal-policies \
                --enable-storeio \
                --enable-delay-pools \
                --enable-wccp \
                --enable-wccpv2 \
                --enable-snmp \
                --enable-ipfw \
                --enable-pf-transparent \
                --enable-ipv6 \
                --enable-http-violations \
                --enable-follow-x-forwarded-for \
                --enable-cache-digests \
                --enable-ltdl-convenience
    
    # Build and install
    make
    make install
    
    # Create squid user if it doesn't exist
    if ! id -u ${SQUID_USER} &>/dev/null; then
        useradd -r -s /sbin/nologin ${SQUID_USER}
    fi
    
    # Create necessary directories
    mkdir -p ${SQUID_CACHE_DIR}
    mkdir -p ${SQUID_LOG_DIR}
    
    # Set permissions
    chown -R ${SQUID_USER}:${SQUID_GROUP} ${SQUID_CACHE_DIR}
    chown -R ${SQUID_USER}:${SQUID_GROUP} ${SQUID_LOG_DIR}
    chmod 750 ${SQUID_CACHE_DIR}
    chmod 750 ${SQUID_LOG_DIR}
    
    # Initialize cache
    squid -z
    
    info "Squid installation completed"
}

# Configure Squid
configure_squid() {
    info "Configuring Squid..."
    
    # Backup original config
    cp ${SQUID_CONFIG_DIR}/squid.conf ${SQUID_CONFIG_DIR}/squid.conf.bak
    
    # Create new config
    cat > ${SQUID_CONFIG_DIR}/squid.conf << EOF
# Squid configuration file

# Basic configuration
http_port ${SQUID_PORT}
visible_hostname $(hostname)

# Access control
acl SSL_ports port 443
acl Safe_ports port 80          # http
acl Safe_ports port 21          # ftp
acl Safe_ports port 443         # https
acl Safe_ports port 70          # gopher
acl Safe_ports port 210         # wais
acl Safe_ports port 1025-65535  # unregistered ports
acl Safe_ports port 280         # http-mgmt
acl Safe_ports port 488         # gss-http
acl Safe_ports port 591         # filemaker
acl Safe_ports port 777         # multiling http
acl CONNECT method CONNECT

# Deny requests to unsafe ports
http_access deny !Safe_ports

# Deny CONNECT to other than secure SSL ports
http_access deny CONNECT !SSL_ports

# Allow localhost
acl localhost src 127.0.0.1/32 ::1
http_access allow localhost

# Allow local network
acl localnet src 10.0.0.0/8     # RFC1918 possible internal network
acl localnet src 172.16.0.0/12  # RFC1918 possible internal network
acl localnet src 192.168.0.0/16 # RFC1918 possible internal network
acl localnet src fc00::/7       # RFC 4193 local private network range
acl localnet src fe80::/10      # RFC 4291 link-local (directly plugged) machines
http_access allow localnet

# Allow authenticated users
acl authenticated proxy_auth REQUIRED
http_access allow authenticated

# Default deny
http_access deny all

# Cache configuration
cache_dir ufs ${SQUID_CACHE_DIR} ${SQUID_DISK_CACHE} ${SQUID_CACHE_DIR_LEVELS} ${SQUID_CACHE_DIR_L1} ${SQUID_CACHE_DIR_L2}
maximum_object_size ${SQUID_MAX_OBJECT_SIZE}
maximum_object_size_in_memory ${SQUID_MAX_OBJECT_SIZE_IN_MEMORY}
memory_pools on
memory_pools_limit ${SQUID_MEMORY_CACHE}

# Logging
access_log ${SQUID_LOG_DIR}/access.log combined
cache_log ${SQUID_LOG_DIR}/cache.log
cache_store_log ${SQUID_LOG_DIR}/store.log

# Performance tuning
client_persistent_connections on
server_persistent_connections on
pconn_timeout 5 minutes
read_timeout 5 minutes
request_timeout 5 minutes
client_lifetime 1 day
server_lifetime 15 minutes
EOF
    
    # Create systemd service file
    cat > /etc/systemd/system/squid.service << EOF
[Unit]
Description=Squid Web Proxy Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/sbin/squid -f ${SQUID_CONFIG_DIR}/squid.conf
ExecReload=/usr/sbin/squid -k reconfigure
ExecStop=/usr/sbin/squid -k shutdown
PIDFile=/var/run/squid.pid
User=${SQUID_USER}
Group=${SQUID_GROUP}
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable and start Squid
    systemctl enable squid
    systemctl start squid
    
    info "Squid configuration completed"
}

# Configure firewall
configure_firewall() {
    info "Configuring firewall for Squid..."
    
    # Allow Squid port
    firewall-cmd --permanent --add-port=${SQUID_PORT}/tcp
    firewall-cmd --reload
    
    info "Firewall configured for Squid"
}

# Create environment module file
create_module_file() {
    info "Creating environment module file..."
    
    local module_dir="/etc/modulefiles/network"
    mkdir -p "${module_dir}"
    
    cat > "${module_dir}/squid" << EOF
#%Module1.0
proc ModulesHelp { } {
    puts stderr "This module loads Squid proxy server"
    puts stderr "Version ${SQUID_VERSION}"
}

module-whatis "Loads Squid proxy server"

# Environment setup
setenv SQUID_VERSION "${SQUID_VERSION}"
setenv SQUID_PORT "${SQUID_PORT}"
setenv http_proxy "http://localhost:${SQUID_PORT}"
setenv https_proxy "http://localhost:${SQUID_PORT}"
setenv ftp_proxy "http://localhost:${SQUID_PORT}"
setenv all_proxy "http://localhost:${SQUID_PORT}"
setenv HTTP_PROXY "http://localhost:${SQUID_PORT}"
setenv HTTPS_PROXY "http://localhost:${SQUID_PORT}"
setenv FTP_PROXY "http://localhost:${SQUID_PORT}"
setenv ALL_PROXY "http://localhost:${SQUID_PORT}"

# Add to path
prepend-path PATH "/usr/sbin"
prepend-path MANPATH "/usr/share/man"
EOF
    
    chmod 644 "${module_dir}/squid"
    info "Module file created at ${module_dir}/squid"
}

# Main execution
main() {
    ensure_dir "$LOG_DIR"
    
    info "Starting Squid installation..."
    
    install_dependencies
    install_squid
    configure_squid
    configure_firewall
    create_module_file
    
    info "Squid installation and configuration completed"
    info "Use 'module load network/squid' to set proxy environment variables"
}

main "$@" 