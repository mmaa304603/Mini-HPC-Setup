#!/bin/bash

# Source common functions
source "$(dirname "$0")/../common/functions.sh"

# Check if running as root
check_root

# Install dependencies for Spack
install_spack_dependencies() {
    info "Installing Spack dependencies..."
    
    local packages=(
        "git"
        "gcc"
        "gcc-c++"
        "make"
        "cmake"
        "python3"
        "python3-pip"
        "environment-modules"
    )
    
    for package in "${packages[@]}"; do
        install_package "$package"
    done
}

# Clone and install Spack
install_spack() {
    info "Installing Spack..."
    
    # Create Spack installation directory
    ensure_dir "$SPACK_INSTALL_DIR"
    
    # Clone Spack repository
    if [ ! -d "$SPACK_INSTALL_DIR/.git" ]; then
        info "Cloning Spack repository..."
        git clone -b "$SPACK_BRANCH" "$SPACK_REPO" "$SPACK_INSTALL_DIR" || {
            error "Failed to clone Spack repository"
            return 1
        }
    else
        info "Spack repository already exists, updating..."
        cd "$SPACK_INSTALL_DIR" && git pull || {
            error "Failed to update Spack repository"
            return 1
        }
    fi
    
    # Create Spack environment file
    cat > /etc/profile.d/spack.sh << EOF
# Spack environment setup
export SPACK_ROOT=$SPACK_INSTALL_DIR
source \$SPACK_ROOT/share/spack/setup-env.sh
EOF
    chmod +x /etc/profile.d/spack.sh
    
    # Source Spack environment
    source /etc/profile.d/spack.sh
    
    # Configure Spack
    configure_spack
}

# Configure Spack
configure_spack() {
    info "Configuring Spack..."
    
    # Add compilers
    for compiler in "${SPACK_COMPILERS[@]}"; do
        info "Adding compiler $compiler..."
        spack compiler find "$compiler" || {
            warn "Failed to add compiler $compiler"
        }
    done
    
    # Configure Spack to use system packages when possible
    spack config add "packages:all:buildable:False"
    spack config add "packages:all:externals:[]"
    
    # Configure Spack to use system compilers
    spack config add "compilers:all:paths:cc:/usr/bin/gcc"
    spack config add "compilers:all:paths:cxx:/usr/bin/g++"
    spack config add "compilers:all:paths:f77:/usr/bin/gfortran"
    spack config add "compilers:all:paths:fc:/usr/bin/gfortran"
    
    # Configure Spack to use system MPI
    spack config add "packages:openmpi:externals:[]"
    
    # Configure Spack to use system Python
    spack config add "packages:python:externals:[]"
}

# Install Spack packages
install_spack_packages() {
    info "Installing Spack packages..."
    
    # Source Spack environment
    source /etc/profile.d/spack.sh
    
    # Install packages
    for package in "${SPACK_PACKAGES[@]}"; do
        info "Installing package $package..."
        spack install "$package" || {
            error "Failed to install package $package"
            return 1
        }
    done
    
    # Generate module files
    spack module tcl refresh -y
}

# Main execution
main() {
    ensure_dir "$LOG_DIR"
    
    # Install dependencies
    install_spack_dependencies
    
    # Install Spack
    install_spack
    
    # Install packages
    install_spack_packages
    
    info "Spack installation completed successfully"
}

main "$@" 