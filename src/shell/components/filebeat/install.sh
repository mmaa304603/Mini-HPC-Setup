#!/bin/bash

# Source common functions
source "$(dirname "$0")/../common/functions.sh"

# Check if running as root
check_root

# Install dependencies for Filebeat
install_filebeat_dependencies() {
    info "Installing Filebeat dependencies..."
    
    local packages=(
        "wget"
        "curl"
        "unzip"
        "tar"
        "gzip"
    )
    
    for package in "${packages[@]}"; do
        install_package "$package"
    done
}

# Install Filebeat
install_filebeat() {
    info "Installing Filebeat..."
    
    # Download Filebeat
    local fb_version="7.17.0"
    local fb_url="https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-${fb_version}-x86_64.rpm"
    local fb_rpm="/tmp/filebeat-${fb_version}-x86_64.rpm"
    
    download_file "$fb_url" "$fb_rpm" || {
        error "Failed to download Filebeat"
        return 1
    }
    
    # Install Filebeat
    install_package "$fb_rpm" || {
        error "Failed to install Filebeat"
        return 1
    }
    
    # Configure Filebeat
    configure_filebeat
    
    # Start Filebeat
    systemctl enable filebeat
    systemctl start filebeat
    
    info "Filebeat installed and started successfully"
}

# Configure Filebeat
configure_filebeat() {
    info "Configuring Filebeat..."
    
    # Backup original config
    cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.bak
    
    # Create new config
    cat > /etc/filebeat/filebeat.yml << EOF
filebeat.config:
  modules:
    path: \${path.config}/modules.d/*.yml
    reload.enabled: false

filebeat.autodiscover:
  providers:
    - type: docker
      hints.enabled: true

processors:
  - add_host_metadata: ~
  - add_cloud_metadata: ~
  - add_docker_metadata: ~

output.elasticsearch:
  hosts: ["{{ elasticsearch_host }}:9200"]
  username: "{{ elasticsearch_user }}"
  password: "{{ elasticsearch_password }}"

setup.kibana:
  host: "{{ kibana_host }}:5601"
  username: "{{ elasticsearch_user }}"
  password: "{{ elasticsearch_password }}"

setup.template.name: "filebeat"
setup.template.pattern: "filebeat-*"
setup.ilm.enabled: false

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 7
  permissions: 0644
EOF
    
    # Configure modules
    filebeat modules enable system
    filebeat modules enable slurm
    
    # Configure system module
    cat > /etc/filebeat/modules.d/system.yml << EOF
- module: system
  syslog:
    enabled: true
    var.paths: ["/var/log/messages", "/var/log/syslog"]
  auth:
    enabled: true
    var.paths: ["/var/log/auth.log", "/var/log/secure"]
EOF
    
    # Configure SLURM module
    cat > /etc/filebeat/modules.d/slurm.yml << EOF
- module: slurm
  job:
    enabled: true
    var.paths: ["/var/log/slurm/job_completion.log"]
  accounting:
    enabled: true
    var.paths: ["/var/log/slurm/accounting.log"]
EOF
    
    # Create log directory
    mkdir -p /var/log/filebeat
    chown -R root:root /var/log/filebeat
    
    info "Filebeat configured successfully"
}

# Main execution
main() {
    ensure_dir "$LOG_DIR"
    
    # Install dependencies
    install_filebeat_dependencies
    
    # Install and configure Filebeat
    install_filebeat
    
    info "Filebeat installation completed successfully"
}

main "$@" 