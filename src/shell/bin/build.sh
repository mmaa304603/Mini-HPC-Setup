#!/bin/bash

# Build Script
# Version: 1.0.0

# Configuration
SCRIPT_DIR="$(dirname "$0")"
LOG_FILE="$SCRIPT_DIR/../logs/build.log"
BUILD_DIR="$SCRIPT_DIR/../build"
SOURCE_DIR="$SCRIPT_DIR/../src"

# Logging setup
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Error handling
handle_error() {
    log "ERROR: $1"
    exit 1
}

# Clean build directory
clean_build() {
    log "Cleaning build directory..."
    rm -rf "$BUILD_DIR"/* || handle_error "Failed to clean build directory"
}

# Build components
build_components() {
    log "Building components..."
    
    # Build shell scripts
    log "Building shell scripts..."
    mkdir -p "$BUILD_DIR/shell"
    cp -r "$SOURCE_DIR/shell"/* "$BUILD_DIR/shell/" || handle_error "Failed to copy shell scripts"
    
    # Build Ansible playbooks
    log "Building Ansible playbooks..."
    mkdir -p "$BUILD_DIR/ansible"
    cp -r "$SOURCE_DIR/ansible"/* "$BUILD_DIR/ansible/" || handle_error "Failed to copy Ansible playbooks"
    
    # Build documentation
    log "Building documentation..."
    mkdir -p "$BUILD_DIR/docs"
    cp -r "$SOURCE_DIR/docs"/* "$BUILD_DIR/docs/" || handle_error "Failed to copy documentation"
}

# Verify build
verify_build() {
    log "Verifying build..."
    
    # Check for required files
    for file in "$BUILD_DIR/shell/install.sh" \
                "$BUILD_DIR/ansible/site.yml" \
                "$BUILD_DIR/docs/README.md"; do
        if [ ! -f "$file" ]; then
            handle_error "Missing required file: $file"
        fi
    done
    
    # Verify file permissions
    find "$BUILD_DIR" -type f -name "*.sh" -exec chmod +x {} \; || handle_error "Failed to set executable permissions"
}

# Create package
create_package() {
    log "Creating package..."
    
    # Create package directory
    PACKAGE_DIR="$BUILD_DIR/package"
    mkdir -p "$PACKAGE_DIR" || handle_error "Failed to create package directory"
    
    # Copy build files to package
    cp -r "$BUILD_DIR"/* "$PACKAGE_DIR/" || handle_error "Failed to copy files to package"
    
    # Create package archive
    cd "$BUILD_DIR" || handle_error "Failed to change to build directory"
    tar -czf "hpc-package-$(date +%Y%m%d).tar.gz" package/ || handle_error "Failed to create package archive"
}

# Main function
main() {
    log "Starting build process"
    
    # Clean build directory
    clean_build
    
    # Build components
    build_components
    
    # Verify build
    verify_build
    
    # Create package
    create_package
    
    log "Build process completed successfully"
}

# Execute main function
main "$@" 