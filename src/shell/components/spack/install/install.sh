#!/bin/bash
set -euo pipefail

# Source common functions and configuration
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

source "${SCRIPT_DIR}/../../../lib/functions.sh"
source "${SCRIPT_DIR}/../../../lib/config.sh"

load_component_config "spack" 2>/dev/null || true

# Install Spack
install_spack() {
    info "Cloning Spack repository ..." 

    if [ -x "$SPACK_ROOT/bin/spack" ] && [ -f "$SPACK_ROOT/share/spack/setup-env.sh" ]; then
        info "Existing Spack installation found at $SPACK_ROOT; skipping clone"
    else        
        warn "$SPACK_ROOT partially installed or not installed at all, cloning again..."
        rm -rf "$SPACK_ROOT"
        git clone https://github.com/spack/spack.git "$SPACK_ROOT"
    fi
    
    # Set up environment
cat > "$SPACK_ENV_FILE" << EOF
export SPACK_ROOT=$SPACK_ROOT
export SPACK_SYSTEM_CONFIG_PATH=/etc/spack
export SPACK_USER_CONFIG_PATH=/etc/spack/no-user-config
unset SPACK_DISABLE_LOCAL_CONFIG
export PATH=\$SPACK_ROOT/bin:\$PATH
if [ -f "\$SPACK_ROOT/share/spack/setup-env.sh" ]; then
    . "\$SPACK_ROOT/share/spack/setup-env.sh"
fi
EOF

    # Minimal compiler/build dependencies
    dnf -y install \
    gcc gcc-c++ gcc-gfortran \
    make patch tar gzip bzip2 xz unzip \
    findutils git which file

    echo "setting up system-wide spack configuration..."
    bash "${SCRIPT_DIR}/../config/setup_system_spack_config.sh"

    echo "sourcing spack_env_file..."
    source "$SPACK_ENV_FILE"

    # Verify system compiler configured by setup_system_spack_config.sh
    spack compiler list

    # Install module system
    if [ "$MODULES_ENABLED" = "true" ]; then
        spack install "$MODULES_TYPE"
    fi

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

    # Generate module files
    if [ "$MODULES_REFRESH" = "true" ]; then
        spack module "$MODULES_TYPE" refresh -y
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
