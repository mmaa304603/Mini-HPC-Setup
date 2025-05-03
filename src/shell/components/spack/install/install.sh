#!/bin/bash

# Source common functions and configuration
source "$(dirname "$0")/../common/functions.sh"
source "$(dirname "$0")/../common/config.sh"

# Install Spack
install_spack() {
    info "Installing Spack..."
    
    # Clone Spack repository
    git clone https://github.com/spack/spack.git "$SPACK_ROOT"
    
    # Set up environment
    cat > "$SPACK_ENV_FILE" << EOF
export SPACK_ROOT=$SPACK_ROOT
export PATH=\$SPACK_ROOT/bin:\$PATH
EOF
    
    source "$SPACK_ENV_FILE"
    
    info "Spack installed successfully"
}

# Install common packages
install_packages() {
    info "Installing common packages..."
    
    # Install packages from configuration
    for package in "${PACKAGES[@]}"; do
        info "Installing package: $package"
        spack install "$package" || {
            warn "Failed to install package: $package"
        }
    done
    
    info "Common packages installed successfully"
}

# Configure environment modules
configure_modules() {
    if [ "$MODULES_ENABLED" != "true" ]; then
        info "Environment modules configuration is disabled"
        return 0
    fi
    
    info "Configuring environment modules..."
    
    # Enable environment modules
    spack config add "modules:enable:$MODULES_TYPE"
    
    # Generate module files
    if [ "$MODULES_REFRESH" = "true" ]; then
        spack module "$MODULES_TYPE" refresh
    fi
    
    info "Environment modules configured successfully"
}

# Main execution
main() {
    check_root
    
    install_spack
    install_packages
    configure_modules
    
    info "Spack installation and configuration completed successfully"
}

main "$@" 