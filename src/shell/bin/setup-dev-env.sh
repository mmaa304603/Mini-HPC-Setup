#!/bin/bash
set -euo pipefail

# Development Environment Setup Script
# Version: 1.0.0

# Configuration
SCRIPT_DIR="$(dirname "$0")"
LOG_FILE="$SCRIPT_DIR/../logs/setup-dev-env.log"
CONFIG_FILE="$SCRIPT_DIR/../config/dev-env.conf"

check_directory() {
    # Create development directories - moved from install_dev_tools()
    mkdir -p "$SCRIPT_DIR/../build" \
             "$SCRIPT_DIR/../logs" \
             "$SCRIPT_DIR/../temp" \
        || handle_error "Failed to create development directories"
}

# Logging setup
log() {
    touch "$LOG_FILE" || {
        echo "ERROR: Failed to create log file: $LOG_FILE" >&2
        exit 1
    }
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Error handling
handle_error() {
    log "ERROR: $1"
    exit 1
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    local tools=(
        "git:git"
        "make:make"
        "gcc:gcc"
        "python3:python3"
        "pip:python3-pip"
    )

    for item in "${tools[@]}"; do
        install_missing_packages "${item%%:*}" "${item##*:}"
    done
}

install_missing_packages() {
    local cmd="$1"
    local package="${2:-$cmd}"

    if ! command -v "$cmd" >/dev/null 2>&1; then
        log "$cmd not found. Installing $package..."
        sudo dnf install -y "$package"\
        || handle_error "Failed to install $package"
    else
        log "$cmd is already installed"
    fi
}

# Install development tools
install_dev_tools() {
    log "Installing development tools..."
    
    # Install build tools
    sudo dnf groupinstall -y "Development Tools" || handle_error "Failed to install development tools"
    
    # Install Python development packages - disabled as requirements file didnt exist
    # pip install -r "$SCRIPT_DIR/../requirements-dev.txt" || handle_error "Failed to install Python packages"
    
    # Install additional development tools
    sudo dnf install -y \
        cmake \
        autoconf \
        automake \
        libtool \
        pkg-config \
        || handle_error "Failed to install additional development tools"
}

# Setup development environment
setup_environment() {
    log "Setting up development environment..."
    
    # Setup environment variables
    cat > "$SCRIPT_DIR/../.env" << EOF
export DEV_ROOT="$(realpath "$SCRIPT_DIR/../")"
export PATH="\$DEV_ROOT/bin:\$PATH"
export PYTHONPATH="\$DEV_ROOT/src:\${PYTHONPATH:-}"
EOF
    
    # Source environment
    source "$SCRIPT_DIR/../.env" || handle_error "Failed to source environment"
}

# Main function
main() {
    # Check directories
    check_directory
    
    log "Starting development environment setup"

    # Check prerequisites
    check_prerequisites
    
    # Install development tools
    install_dev_tools
    
    # Setup environment
    setup_environment
    
    log "Development environment setup completed successfully"
}

# Execute main function
main "$@" 