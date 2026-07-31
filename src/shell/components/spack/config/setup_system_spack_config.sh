#!/bin/bash
set -euo pipefail

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
SPACK_ENV_FILE="/etc/profile.d/spack.sh"
SPACK_DISABLED_USER_CONFIG_DIR="$SPACK_CONFIG_DIR/no-user-config"
SPACK_SYSTEM_COMPILER_DIR="/usr/bin"
SPACK_COMPILER_PREFIX="/usr"

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run with sudo privileges${NC}"
    exit 1
fi

# Create Spack configuration directory if it doesn't exist
echo -e "${BLUE}Creating Spack configuration directory...${NC}"
mkdir -p "$SPACK_CONFIG_DIR"
mkdir -p "$SPACK_DISABLED_USER_CONFIG_DIR"

if [ ! -x "$SPACK_SYSTEM_COMPILER_DIR/gcc" ]; then
    echo -e "${RED}Error: $SPACK_SYSTEM_COMPILER_DIR/gcc is required before configuring Spack${NC}"
    exit 1
fi

if [ ! -x "$SPACK_SYSTEM_COMPILER_DIR/g++" ]; then
    echo -e "${RED}Error: $SPACK_SYSTEM_COMPILER_DIR/g++ is required before configuring Spack${NC}"
    exit 1
fi

if [ ! -x "$SPACK_SYSTEM_COMPILER_DIR/gfortran" ]; then
    echo -e "${RED}Error: $SPACK_SYSTEM_COMPILER_DIR/gfortran is required before configuring Spack${NC}"
    exit 1
fi

GCC_VERSION="$("$SPACK_SYSTEM_COMPILER_DIR/gcc" -dumpfullversion -dumpversion)"
SPACK_OPERATING_SYSTEM="linux"
SPACK_TARGET="$(uname -m)"

if [ -f /etc/os-release ]; then
    source /etc/os-release
    SPACK_OPERATING_SYSTEM="${ID}${VERSION_ID%%.*}"
fi

echo -e "${BLUE}Writing system-wide Spack configuration...${NC}"
cat > "$SPACK_CONFIG_DIR/config.yaml" << EOF
config:
  install_tree:
    root: $SPACK_INSTALL_DIR/opt/spack
    projections:
      all: '{name}/{version}-{compiler.name}-{compiler.version}/{hash}'
  build_stage:
    - /tmp/spack-stage
  source_cache: $SPACK_INSTALL_DIR/sources
  misc_cache: $SPACK_INSTALL_DIR/cache
  module_roots:
    tcl: $SPACK_INSTALL_DIR/modules/tcl
    lmod: $SPACK_INSTALL_DIR/modules/lmod
  build_language: C
  build_jobs: 8
EOF

cat > "$SPACK_CONFIG_DIR/packages.yaml" << EOF
packages:
  all:
    compiler: [gcc]
  gcc:
    externals:
      - spec: gcc@=${GCC_VERSION} languages=c,cxx,fortran os=${SPACK_OPERATING_SYSTEM} target=${SPACK_TARGET}
        prefix: $SPACK_COMPILER_PREFIX
        extra_attributes:
          compilers:
            c: $SPACK_SYSTEM_COMPILER_DIR/gcc
            cxx: $SPACK_SYSTEM_COMPILER_DIR/g++
            fortran: $SPACK_SYSTEM_COMPILER_DIR/gfortran
    buildable: false
EOF

cat > "$SPACK_CONFIG_DIR/modules.yaml" << EOF
modules:
  default:
    enable:
      - lmod
    roots:
      tcl: $SPACK_INSTALL_DIR/modules/tcl
      lmod: $SPACK_INSTALL_DIR/modules/lmod
EOF

echo -e "${BLUE}Creating system-wide environment file...${NC}"
cat > "$SPACK_ENV_FILE" << EOF
# Spack environment setup
export SPACK_ROOT=$SPACK_INSTALL_DIR
export SPACK_SYSTEM_CONFIG_PATH=$SPACK_CONFIG_DIR
export SPACK_USER_CONFIG_PATH=$SPACK_DISABLED_USER_CONFIG_DIR
unset SPACK_DISABLE_LOCAL_CONFIG
export PATH=\$SPACK_ROOT/bin:\$PATH
if [ -f "\$SPACK_ROOT/share/spack/setup-env.sh" ]; then
    . "\$SPACK_ROOT/share/spack/setup-env.sh"
fi
EOF

echo -e "${BLUE}Setting permissions...${NC}"
chmod 644 "$SPACK_CONFIG_DIR/config.yaml" "$SPACK_CONFIG_DIR/packages.yaml" "$SPACK_CONFIG_DIR/modules.yaml"
chown root:root "$SPACK_CONFIG_DIR/config.yaml" "$SPACK_CONFIG_DIR/packages.yaml" "$SPACK_CONFIG_DIR/modules.yaml"
chmod 755 "$SPACK_DISABLED_USER_CONFIG_DIR"
chown root:root "$SPACK_DISABLED_USER_CONFIG_DIR"
chmod 644 "$SPACK_ENV_FILE"
chown root:root "$SPACK_ENV_FILE"

if [ -x "$SPACK_INSTALL_DIR/bin/spack" ]; then
    echo -e "${BLUE}Verifying system compiler configuration...${NC}"
    source "$SPACK_ENV_FILE"
    spack compiler list
else
    echo -e "${YELLOW}Warning: $SPACK_INSTALL_DIR/bin/spack not found; skipping compiler verification${NC}"
fi

echo -e "\n${GREEN}System-wide Spack configuration setup completed successfully!${NC}"
echo -e "\nConfiguration files installed in $SPACK_CONFIG_DIR/:"
echo -e "$SPACK_CONFIG_DIR/config.yaml"
echo -e "$SPACK_CONFIG_DIR/packages.yaml"
echo -e "$SPACK_CONFIG_DIR/modules.yaml"
echo -e "\nEnvironment file created at $SPACK_ENV_FILE"
echo -e "\nTo apply the changes, users need to either:"
echo -e "1. Log out and log back in"
echo -e "2. Run: source $SPACK_ENV_FILE"
