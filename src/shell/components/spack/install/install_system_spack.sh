#!/bin/bash

# Script to install Spack package manager at system level
# This script should be run with sudo privileges

set -e  # Exit on error

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

CONFIG_SCRIPT="${SCRIPT_DIR}/../config/setup_system_spack_config.sh"
PROFILE_FILE="/etc/profile.d/spack.sh"
NETWORK_CONFIG="${SCRIPT_DIR}/../../network/network.conf"

# Configuration
SPACK_VERSION="v0.23.1"
SPACK_INSTALL_DIR="/opt/spack"  # System-wide Spack installation
SPACK_CONFIG_DIR="/etc/spack"   # System-wide Spack configurations
SPACK_REPO="https://github.com/spack/spack.git"
SPACK_CPU_IMAGE_NAME="rockylinux-9.6"
TEMP_DIR=$(mktemp -d)           # Temporary directory for cloning
SPACK_INSTALL_NEEDED=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status messages
print_status() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print warnings
print_warning() {
    echo -e "${YELLOW}Warning: $1${NC}"
}

# Function to print errors
print_error() {
    echo -e "${RED}Error: $1${NC}"
}

# Function to cleanup temporary directory
cleanup() {
    echo "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    print_status "Cleanup completed"
}

# Set up cleanup trap
trap cleanup EXIT

installed_spack_version() {
    if [ -d "$SPACK_INSTALL_DIR/.git" ]; then
        git -C "$SPACK_INSTALL_DIR" describe --tags --exact-match 2>/dev/null ||
            git -C "$SPACK_INSTALL_DIR" rev-parse --short HEAD 2>/dev/null
    elif [ -x "$SPACK_INSTALL_DIR/bin/spack" ]; then
        "$SPACK_INSTALL_DIR/bin/spack" --version 2>/dev/null
    fi
}

check_existing_spack_installation() {
    local installed_version=""

    if [ ! -d "$SPACK_INSTALL_DIR" ]; then
        return 0
    fi

    installed_version="$(installed_spack_version || true)"
    if [ "$installed_version" = "$SPACK_VERSION" ]; then
        print_status "Spack $SPACK_VERSION is already installed at $SPACK_INSTALL_DIR; skipping installation"
        SPACK_INSTALL_NEEDED=false
    elif [ -n "$installed_version" ]; then
        print_warning "Found Spack $installed_version at $SPACK_INSTALL_DIR; requested $SPACK_VERSION"
    else
        print_warning "$SPACK_INSTALL_DIR exists but no Spack version could be detected"
    fi
}

# Function to check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."
    
    # Check if running with sudo
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run with sudo privileges"
        exit 1
    fi
    
    # Check Python version
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is required but not found"
        exit 1
    fi
    
    # Check required Python packages
    missing_packages=()
    for package in clingo yaml jinja2; do
        if ! python3 -c "import $package" &> /dev/null; then
            missing_packages+=($package)
        fi
    done

    if ! python3 -m pip --version >/dev/null 2>&1; then
        dnf install -y python3-pip
    fi

    if [ ${#missing_packages[@]} -ne 0 ]; then
    print_warning "Installing missing Python packages:"
    printf '%s\n' "${missing_packages[@]}"
        if ! python3 -m pip install "${missing_packages[@]}"; then
            print_warning "Failed to install one or more Python packages."
            exit 1
        fi
    fi
    
    print_status "All prerequisites satisfied"
}

# Function to handle existing directory
handle_existing_directory() {
    local dir=$1
    local dir_type=$2
    
    if [ -d "$dir" ]; then
        if [ -z "$(ls -A $dir)" ]; then
            # Directory is empty, safe to use
            return 0
        else
            echo "$dir_type directory $dir already exists and is not empty."
            echo "Options:"
            echo "1. Backup existing directory and create new one"
            echo "2. Remove existing directory and create new one"
            echo "3. Exit"
            read -t 5 -p "Choose an option [1-3] (default: 1 in 5 seconds): " choice || choice=1
            echo
            
            case $choice in
                1)
                    parent_dir="$(dirname "$dir")"
                    base_dir="$(basename "$dir")"

                    echo "Removing old backups for $dir..."
                    find "$parent_dir" -maxdepth 1 -type d -name "${base_dir}_backup_*" -exec rm -rf {} +

                    backup_dir="${dir}_backup_$(date +%Y%m%d_%H%M%S)"
                    echo "Backing up existing directory to $backup_dir"
                    mv "$dir" "$backup_dir"
                    return 0
                    ;;
                2)
                    echo "Removing existing directory"
                    rm -rf "$dir"
                    return 0
                    ;;
                3)
                    echo "Exiting..."
                    exit 1
                    ;;
                *)
                    print_error "Invalid option"
                    exit 1
                    ;;
            esac
        fi
    fi
}

# Function to create directory structure
create_directory_structure() {
    echo "Setting up directory structure..."

    if [ "$SPACK_INSTALL_NEEDED" = true ]; then
        handle_existing_directory "$SPACK_INSTALL_DIR" "Spack installation"
    fi
    handle_existing_directory "$SPACK_CONFIG_DIR" "Spack configuration"
    
    # Create directories
    mkdir -p "$SPACK_INSTALL_DIR"
    mkdir -p "$SPACK_CONFIG_DIR"
    
    # Set proper permissions
    chmod 755 "$SPACK_INSTALL_DIR"
    chmod 755 "$SPACK_CONFIG_DIR"
    
    print_status "Directory structure created"
}

install_system_dependencies() {
    echo "Installing system compiler and build dependencies..."

    dnf -y install \
        gcc gcc-c++ gcc-gfortran \
        make patch tar gzip bzip2 xz unzip \
        findutils git which file

    print_status "System dependencies installed"
}

# Function to install Spack
install_spack() {
    if [ "$SPACK_INSTALL_NEEDED" != true ]; then
        return 0
    fi

    echo "Installing Spack $SPACK_VERSION..."
    
    # Clone Spack repository to temporary directory
    echo "Cloning Spack repository to temporary directory..."
    git clone "$SPACK_REPO" "$TEMP_DIR/spack"
    
    # Change to temporary Spack directory
    cd "$TEMP_DIR/spack"
    
    # Fetch all tags
    git fetch --tags
    
    # Checkout specific version
    if ! git checkout "$SPACK_VERSION"; then
        print_error "Failed to checkout Spack version $SPACK_VERSION"
        exit 1
    fi
    
    # Move files to final location
    echo "Moving Spack to final location..."
    cp -r . "$SPACK_INSTALL_DIR/"
    
    # Set proper permissions
    chown -R root:root "$SPACK_INSTALL_DIR"
    chmod -R 755 "$SPACK_INSTALL_DIR"
    
    print_status "Spack installed successfully"
}

configure_spack() {
    if [ -f "$CONFIG_SCRIPT" ]; then
        echo "Running Spack system configuration script..."
        bash "$CONFIG_SCRIPT"
    else
        print_error "Spack configuration script not found: $CONFIG_SCRIPT"
        exit 1
    fi

    if ! source "$PROFILE_FILE"; then
        echo "Failed to source profile file"
        return 1
    fi

    spack compiler list

    print_status "Spack configured successfully"
}

configure_compute_node_spack_access() {
    local head_node_ip="${HEAD_NODE_IP:-10.0.0.1}"

    if [ -f "$NETWORK_CONFIG" ]; then
        source "$NETWORK_CONFIG"
        head_node_ip="${HEAD_NODE_IP:-$head_node_ip}"
    fi

    if ! command -v wwctl >/dev/null 2>&1; then
        print_warning "wwctl not found; skipping Spack access configuration in Warewulf CPU image"
        return 0
    fi

    if ! wwctl image list | grep -q "$SPACK_CPU_IMAGE_NAME"; then
        print_error "Warewulf image $SPACK_CPU_IMAGE_NAME not found; cannot configure compute-node Spack access"
        wwctl image list || true
        return 1
    fi

    if [ ! -f "$PROFILE_FILE" ]; then
        print_error "Missing $PROFILE_FILE; cannot configure compute-node Spack access"
        return 1
    fi

    echo "Configuring compute-node Spack access in Warewulf image $SPACK_CPU_IMAGE_NAME..."

    wwctl image exec \
        --bind "$PROFILE_FILE:/tmp/spack.sh:ro" \
        "$SPACK_CPU_IMAGE_NAME" -- \
        /usr/bin/env HEAD_NODE_IP="$head_node_ip" \
        /bin/bash -c '
            set -e
            export PATH=/usr/sbin:/usr/bin:/sbin:/bin

            echo "Installing configuring packages..."
            dnf -y install nfs-utils
            mkdir -p /opt /etc/profile.d
            install -o root -g root -m 0644 /tmp/spack.sh /etc/profile.d/spack.sh

            mkdir -p /etc
            touch /etc/fstab
            chmod 0644 /etc/fstab
            sed -i "/ \/opt /d" /etc/fstab
            printf "%s:/opt /opt nfs4 ro,nofail,_netdev,x-systemd.automount 0 0\n" "$HEAD_NODE_IP" >> /etc/fstab

            echo "Enabling remote filesystem support..."
            systemctl enable remote-fs.target

            echo "Verifying Spack profile script..."
            test -f /etc/profile.d/spack.sh

            echo "Verifying /opt NFS mount entry..."
            findmnt --fstab --mountpoint /opt --types nfs,nfs4 >/dev/null
        '

    wwctl image build "$SPACK_CPU_IMAGE_NAME"
    wwctl overlay build || true
    
    print_status "Compute-node Spack access configured"
}

# Main installation process
echo "Starting system-wide Spack installation..."

# Check prerequisites
check_prerequisites

# Check existing Spack installation before modifying installation directory
check_existing_spack_installation

# Create directory structure
create_directory_structure

# Install compiler and build dependencies before registering compilers
install_system_dependencies

# Install Spack
install_spack

# Configure Spack and register system compilers
configure_spack

# Configure Warewulf compute nodes to use the head-node Spack tree when available
configure_compute_node_spack_access

# echo "System-wide Spack installation completed successfully!"
# echo "Next steps:"
# echo "1. Run setup_system_spack_config.sh to configure Spack"
# echo "2. Add the following to /etc/profile.d/spack.sh:"
# echo "   export SPACK_ROOT=$SPACK_INSTALL_DIR"
# echo "   export PATH=\$SPACK_ROOT/bin:\$PATH"
# echo ""
echo "Directory structure:"
echo "- Spack installation: $SPACK_INSTALL_DIR"
echo "- Spack configuration: $SPACK_CONFIG_DIR"
