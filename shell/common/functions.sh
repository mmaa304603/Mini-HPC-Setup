#!/bin/bash

# Source configuration
source "$(dirname "$0")/config.sh"

# Logging functions
log() {
    local level=$1
    shift
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*" | tee -a "$LOG_FILE"
}

info() { log "INFO" "$*"; }
error() { log "ERROR" "$*"; }
warn() { log "WARN" "$*"; }

# Check if running as root
check_root() {
    if [ "$(id -u)" != "0" ]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install package if not present
install_package() {
    local package=$1
    if ! command_exists "$package"; then
        info "Installing $package..."
        dnf install -y "$package" || {
            error "Failed to install $package"
            return 1
        }
    else
        info "$package is already installed"
    fi
}

# Configure firewall
configure_firewall() {
    local port=$1
    local service=$2
    info "Configuring firewall for $service on port $port..."
    firewall-cmd --permanent --add-port="$port/tcp" || {
        error "Failed to add port $port to firewall"
        return 1
    }
    firewall-cmd --reload || {
        error "Failed to reload firewall"
        return 1
    }
}

# Create directory if it doesn't exist
ensure_dir() {
    local dir=$1
    if [ ! -d "$dir" ]; then
        info "Creating directory $dir..."
        mkdir -p "$dir" || {
            error "Failed to create directory $dir"
            return 1
        }
    fi
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

# Start and enable a service
start_service() {
    local service=$1
    info "Starting and enabling $service..."
    systemctl enable "$service" || {
        error "Failed to enable $service"
        return 1
    }
    systemctl start "$service" || {
        error "Failed to start $service"
        return 1
    }
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