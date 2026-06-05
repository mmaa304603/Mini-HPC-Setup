#!/bin/bash
set -euo pipefail

# Source common functions and configuration
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

source "${SCRIPT_DIR}/../../../lib/functions.sh"
source "${SCRIPT_DIR}/../../../lib/config.sh"
source "${SCRIPT_DIR}/../spack.conf"

# Install Spack
install_spack() {
    info "Installing Spack..."

    # Clone Spack repository
    rm -rf "$SPACK_ROOT"
    git clone https://github.com/spack/spack.git "$SPACK_ROOT"
    
    # Set up environment
    cat > "$SPACK_ENV_FILE" << EOF
export SPACK_ROOT=$SPACK_ROOT
export PATH=\$SPACK_ROOT/bin:\$PATH
EOF
    
    source "$SPACK_ENV_FILE"
    
    # Minimal compiler/build dependencies
    dnf -y install \
        gcc gcc-c++ gcc-gfortran \
        make patch tar gzip bzip2 xz unzip \
        findutils git which file
    
    # Register system compiler with Spack
    spack compiler find
    spack compilers
    
    info "Spack installed successfully"
}

# Install common packages
install_packages() {
    info "Installing common packages..."

    # Install packages from configuration
    for package in "${PACKAGES[@]}"; do
        info "Installing package: $package"
        if spack install "$package"; then info "Installed package: $package"
        else 
            warn "Failed to install package: $package"
            failed=1
        fi
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