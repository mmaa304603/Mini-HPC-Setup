#!/bin/bash

# Script to setup system-wide Spack configuration
# This script should be run with sudo privileges

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SPACK_INSTALL_DIR="/opt/spack"
SPACK_CONFIG_DIR="/etc/spack"

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run with sudo privileges${NC}"
    exit 1
fi

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Create Spack configuration directory if it doesn't exist
echo -e "${BLUE}Creating Spack configuration directory...${NC}"
mkdir -p "$SPACK_CONFIG_DIR"

# Copy configuration files
echo -e "${BLUE}Copying configuration files...${NC}"

# Copy spack.yaml
if [ -f "$REPO_ROOT/.spack/spack.yaml" ]; then
    cp "$REPO_ROOT/.spack/spack.yaml" "$SPACK_CONFIG_DIR/"
    echo -e "${GREEN}✓${NC} Copied spack.yaml"
else
    echo -e "${YELLOW}Warning: spack.yaml not found in repository${NC}"
fi

# Copy config.yaml
if [ -f "$REPO_ROOT/.spack/config.yaml" ]; then
    cp "$REPO_ROOT/.spack/config.yaml" "$SPACK_CONFIG_DIR/"
    echo -e "${GREEN}✓${NC} Copied config.yaml"
else
    echo -e "${YELLOW}Warning: config.yaml not found in repository${NC}"
fi

# Copy compilers.yaml
if [ -f "$REPO_ROOT/.spack/compilers.yaml" ]; then
    cp "$REPO_ROOT/.spack/compilers.yaml" "$SPACK_CONFIG_DIR/"
    echo -e "${GREEN}✓${NC} Copied compilers.yaml"
else
    echo -e "${YELLOW}Warning: compilers.yaml not found in repository${NC}"
fi

# Copy packages.yaml
if [ -f "$REPO_ROOT/.spack/packages.yaml" ]; then
    cp "$REPO_ROOT/.spack/packages.yaml" "$SPACK_CONFIG_DIR/"
    echo -e "${GREEN}✓${NC} Copied packages.yaml"
else
    echo -e "${YELLOW}Warning: packages.yaml not found in repository${NC}"
fi

# Copy modules.yaml
if [ -f "$REPO_ROOT/.spack/modules.yaml" ]; then
    cp "$REPO_ROOT/.spack/modules.yaml" "$SPACK_CONFIG_DIR/"
    echo -e "${GREEN}✓${NC} Copied modules.yaml"
else
    echo -e "${YELLOW}Warning: modules.yaml not found in repository${NC}"
fi

# Set proper permissions
echo -e "${BLUE}Setting permissions...${NC}"
chmod 644 "$SPACK_CONFIG_DIR"/*.yaml
chown root:root "$SPACK_CONFIG_DIR"/*.yaml

# Create system-wide environment file
echo -e "${BLUE}Creating system-wide environment file...${NC}"
cat > "/etc/profile.d/spack.sh" << EOF
# Spack environment setup
export SPACK_ROOT=$SPACK_INSTALL_DIR
export PATH=\$SPACK_ROOT/bin:\$PATH
EOF

chmod 644 "/etc/profile.d/spack.sh"
chown root:root "/etc/profile.d/spack.sh"

echo -e "\n${GREEN}System-wide Spack configuration setup completed successfully!${NC}"
echo -e "\nConfiguration files installed in $SPACK_CONFIG_DIR/:"
echo -e "$SPACK_CONFIG_DIR/"
echo -e "├── spack.yaml"
echo -e "├── config.yaml"
echo -e "├── compilers.yaml"
echo -e "├── packages.yaml"
echo -e "└── modules.yaml"
echo -e "\nEnvironment file created at /etc/profile.d/spack.sh"
echo -e "\nTo apply the changes, users need to either:"
echo -e "1. Log out and log back in"
echo -e "2. Run: source /etc/profile.d/spack.sh" 