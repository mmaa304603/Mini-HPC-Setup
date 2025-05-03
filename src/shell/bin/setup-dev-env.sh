#!/bin/bash

# Development Environment Setup Script
# Version: 1.0.0

# Configuration
SCRIPT_DIR="$(dirname "$0")"
LOG_FILE="$SCRIPT_DIR/../logs/setup-dev-env.log"
CONFIG_FILE="$SCRIPT_DIR/../config/dev-env.conf"

# Logging setup
log() {
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
    
    # Check for required commands
    for cmd in git make gcc python3 pip; do
        if ! command -v $cmd &> /dev/null; then
            handle_error "$cmd is required but not installed"
        fi
    done
    
    # Check for required directories
    for dir in "$SCRIPT_DIR/../build" "$SCRIPT_DIR/../logs"; do
        if [ ! -d "$dir" ]; then
            mkdir -p "$dir" || handle_error "Failed to create directory: $dir"
        fi
    done
}

# Install development tools
install_dev_tools() {
    log "Installing development tools..."
    
    # Install build tools
    sudo dnf groupinstall -y "Development Tools" || handle_error "Failed to install development tools"
    
    # Install Python development packages
    pip install -r "$SCRIPT_DIR/../requirements-dev.txt" || handle_error "Failed to install Python packages"
    
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
    
    # Create development directories
    mkdir -p "$SCRIPT_DIR/../build" \
             "$SCRIPT_DIR/../logs" \
             "$SCRIPT_DIR/../temp" \
        || handle_error "Failed to create development directories"
    
    # Setup environment variables
    cat > "$SCRIPT_DIR/../.env" << EOF
export DEV_ROOT="$(realpath "$SCRIPT_DIR/../")"
export PATH="\$DEV_ROOT/bin:\$PATH"
export PYTHONPATH="\$DEV_ROOT/src:\$PYTHONPATH"
EOF
    
    # Source environment
    source "$SCRIPT_DIR/../.env" || handle_error "Failed to source environment"
}

# Main function
main() {
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