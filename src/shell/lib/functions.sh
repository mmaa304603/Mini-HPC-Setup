#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Log directory
LOG_DIR="/var/log/hpc-setup"

# Print info message
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Print warning message
warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Print error message
error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Create directory if it doesn't exist
ensure_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
    fi
}

# Backup file if it exists
backup_file() {
    if [ -f "$1" ]; then
        cp "$1" "$1.bak"
    fi
}

# Install package using dnf
install_package() {
    info "Installing package: $1"
    dnf install -y "$1" || {
        error "Failed to install package: $1"
        return 1
    }
}

# Start and enable service
start_service() {
    info "Starting service: $1"
    systemctl enable --now "$1" || {
        error "Failed to start service: $1"
        return 1
    }
}

# Configure firewall
configure_firewall() {
    info "Configuring firewall for port: $1"
    firewall-cmd --permanent --add-port="$1/tcp" || {
        error "Failed to configure firewall for port: $1"
        return 1
    }
    firewall-cmd --reload
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Backup a file
backup_file() {
    local file=$1
    if [ -f "$file" ]; then
        local backup="${file}.$(date +%Y%m%d%H%M%S).bak"
        info "Backing up $file to $backup..."
        cp "$file" "$backup" || {
            error "Failed to backup $file"
            return 1
        }
    fi
}

# Check if a service is running
service_running() {
    local service=$1
    systemctl is-active --quiet "$service"
}

# Execute command on remote node
remote_exec() {
    local node=$1
    shift
    ssh "root@$node" "$*" || {
        error "Failed to execute command on $node"
        return 1
    }
} 