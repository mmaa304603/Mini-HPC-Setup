#!/bin/bash

# Base component common functions
# Used by head-install.sh and gpu-install.sh

# Source shared libraries
source "$(dirname "$0")/../../lib/functions.sh"

# Common package lists
get_common_packages() {
    echo "curl wget git vim tmux jq tar unzip zip lsof rsync python3 python3-pip"
}

get_network_tools() {
    echo "net-tools telnet"
}

# Role-specific package lists
get_head_packages() {
    echo "chrony openssh-server nfs-utils tftp-server dhcp-server httpd cockpit pdsh"
}

get_gpu_packages() {
    echo "openssh-server nfs-common chrony htop iotop nvidia-utils-525"
}

# Service management functions
enable_services() {
    local services=("$@")
    for service in "${services[@]}"; do
        info "Enabling service: $service"
        systemctl enable --now "$service" || warn "Failed to enable $service"
    done
}

# User management functions
add_user_to_group() {
    local user="$1"
    local group="$2"
    if command -v "$group" >/dev/null 2>&1; then
        usermod -aG "$group" "$user" || warn "Failed to add $user to $group"
    fi
}


# PDSH configuration for cluster management
configure_pdsh() {
    info "Configuring PDSH for cluster management..."
    
    # Create system-wide PDSH configuration
    cat > /etc/profile.d/pdsh.sh << 'EOF'
# PDSH configuration for HPC cluster management
export PDSH_RCMD_TYPE='ssh'
export WCOLL='/etc/pdsh/machines.list'
EOF
    
    # Create system-wide machines directory and file
    ensure_dir "/etc/pdsh"
    
    # Create initial system-wide machines file
    cat > /etc/pdsh/machines.list << EOF
# System-wide cluster nodes list
# Add your cluster nodes here, one per line
# Example:
# n01
# n02
# n03
# gpu01
EOF
    
    # Create per-user setup script for admins
    cat > /etc/pdsh/setup-user-pdsh.sh << 'EOF'
#!/bin/bash
# Per-user PDSH setup script
# Run this as a regular user to set up personal PDSH configuration

echo "Setting up per-user PDSH configuration..."

# Create user's .dsh directory
mkdir -p ~/.dsh

# Create user's machines list
cat > ~/.dsh/machines.list << 'INNER_EOF'
# Personal cluster nodes list
# Add your cluster nodes here, one per line
# Example:
# n01
# n02
# n03
# gpu01
INNER_EOF

# Add to user's shell profile
if [ -f ~/.bashrc ]; then
    echo 'export WCOLL=$HOME/.dsh/machines.list' >> ~/.bashrc
    echo 'export PDSH_RCMD_TYPE=ssh' >> ~/.bashrc
fi

if [ -f ~/.zshrc ]; then
    echo 'export WCOLL=$HOME/.dsh/machines.list' >> ~/.zshrc
    echo 'export PDSH_RCMD_TYPE=ssh' >> ~/.zshrc
fi

echo "Per-user PDSH setup completed!"
echo "Edit ~/.dsh/machines.list to add your nodes"
echo "Reload your shell or run: source ~/.bashrc"
EOF
    
    # Make scripts executable
    chmod +x /etc/profile.d/pdsh.sh
    chmod +x /etc/pdsh/setup-user-pdsh.sh
    
    info "PDSH configuration completed"
    info ""
    info "System-wide setup:"
    info "  - Edit /etc/pdsh/machines.list to add cluster nodes"
    info "  - All users will use system-wide configuration"
    info ""
    info "Per-user setup (for admins):"
    info "  - Run: /etc/pdsh/setup-user-pdsh.sh"
    info "  - Edit ~/.dsh/machines.list for personal node list"
    info "  - Per-user config overrides system-wide"
    info ""
    info "Test with: pdsh -a 'hostname'"
}
