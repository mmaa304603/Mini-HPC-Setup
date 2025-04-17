#!/bin/bash

# Source common functions
source "$(dirname "$0")/../common/functions.sh"

# Check if running as root
check_root

# Install dependencies for Environment Modules
install_modules_dependencies() {
    info "Installing Environment Modules dependencies..."
    
    local packages=(
        "git"
        "gcc"
        "gcc-c++"
        "make"
        "tcl"
        "tcl-devel"
    )
    
    for package in "${packages[@]}"; do
        install_package "$package"
    done
}

# Clone and install Environment Modules
install_modules() {
    info "Installing Environment Modules..."
    
    # Create Modules installation directory
    ensure_dir "$MODULES_INSTALL_DIR"
    
    # Clone Modules repository
    if [ ! -d "$MODULES_INSTALL_DIR/.git" ]; then
        info "Cloning Environment Modules repository..."
        git clone -b "$MODULES_BRANCH" "$MODULES_REPO" "$MODULES_INSTALL_DIR" || {
            error "Failed to clone Environment Modules repository"
            return 1
        }
    else
        info "Environment Modules repository already exists, updating..."
        cd "$MODULES_INSTALL_DIR" && git pull || {
            error "Failed to update Environment Modules repository"
            return 1
        }
    fi
    
    # Configure and install Modules
    cd "$MODULES_INSTALL_DIR" || return 1
    
    info "Configuring Environment Modules..."
    ./configure --prefix="$MODULES_PREFIX" || {
        error "Failed to configure Environment Modules"
        return 1
    }
    
    info "Building Environment Modules..."
    make || {
        error "Failed to build Environment Modules"
        return 1
    }
    
    info "Installing Environment Modules..."
    make install || {
        error "Failed to install Environment Modules"
        return 1
    }
    
    # Create Modules environment file
    cat > /etc/profile.d/modules.sh << EOF
# Environment Modules setup
export MODULES_PREFIX=$MODULES_PREFIX
export MODULEPATH=$MODULES_DEFAULT_PATH
source \$MODULES_PREFIX/init/bash
EOF
    chmod +x /etc/profile.d/modules.sh
    
    # Create Modules environment file for csh/tcsh
    cat > /etc/profile.d/modules.csh << EOF
# Environment Modules setup
setenv MODULES_PREFIX $MODULES_PREFIX
setenv MODULEPATH $MODULES_DEFAULT_PATH
source \$MODULES_PREFIX/init/csh
EOF
    chmod +x /etc/profile.d/modules.csh
    
    # Source Modules environment
    source /etc/profile.d/modules.sh
    
    # Configure Modules
    configure_modules
}

# Configure Environment Modules
configure_modules() {
    info "Configuring Environment Modules..."
    
    # Create modulefiles directory
    ensure_dir "$MODULES_DEFAULT_PATH"
    
    # Create Spack modulefile
    cat > "$MODULES_DEFAULT_PATH/spack" << EOF
#%Module1.0
##
## Spack modulefile
##

proc ModulesHelp { } {
    puts stderr "This module loads the Spack package manager"
}

module-whatis "Loads the Spack package manager"

set spack_root $SPACK_INSTALL_DIR

prepend-path PATH \$spack_root/bin
prepend-path MANPATH \$spack_root/share/man
prepend-path LD_LIBRARY_PATH \$spack_root/lib
prepend-path LD_LIBRARY_PATH \$spack_root/lib64
prepend-path PKG_CONFIG_PATH \$spack_root/lib/pkgconfig
prepend-path PKG_CONFIG_PATH \$spack_root/lib64/pkgconfig
prepend-path CMAKE_PREFIX_PATH \$spack_root
prepend-path PYTHONPATH \$spack_root/lib/python3.10/site-packages
EOF
    chmod 644 "$MODULES_DEFAULT_PATH/spack"
    
    # Create default modulefile
    cat > "$MODULES_DEFAULT_PATH/.modulefiles" << EOF
#%Module1.0
##
## Default modulefile
##

proc ModulesHelp { } {
    puts stderr "This module sets up the default environment"
}

module-whatis "Sets up the default environment"

# Load Spack
module load spack

# Load common packages
module load openmpi
module load hdf5
module load netcdf
module load python
module load numpy
module load scipy
module load matplotlib
EOF
    chmod 644 "$MODULES_DEFAULT_PATH/.modulefiles"
}

# Main execution
main() {
    ensure_dir "$LOG_DIR"
    
    # Install dependencies
    install_modules_dependencies
    
    # Install Environment Modules
    install_modules
    
    info "Environment Modules installation completed successfully"
}

main "$@" 