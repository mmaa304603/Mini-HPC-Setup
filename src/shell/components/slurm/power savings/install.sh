#!/bin/bash

# Default installation directory
DEFAULT_INSTALL_DIR="/opt/slurm/power-management"
INSTALL_DIR=${1:-$DEFAULT_INSTALL_DIR}

# Function to log installation steps
log_step() {
    echo -e "\033[32m[INSTALL]\033[0m $1"
}

# Function to log errors
log_error() {
    echo -e "\033[31m[ERROR]\033[0m $1"
    exit 1
}

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    log_error "Please run as root"
fi

# Create installation directory
log_step "Creating installation directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR" || log_error "Failed to create installation directory"

# Copy files to installation directory
log_step "Copying files to installation directory"
cp -r config scripts docs tests "$INSTALL_DIR/" || log_error "Failed to copy files"

# Set correct permissions
log_step "Setting permissions"
chmod 755 "$INSTALL_DIR"
chmod 755 "$INSTALL_DIR/scripts/node_management/"*.sh
chmod 755 "$INSTALL_DIR/scripts/slurm/"*.sh
chmod 755 "$INSTALL_DIR/tests/"*.sh
chmod 644 "$INSTALL_DIR/config/"*

# Create log directory if it doesn't exist
log_step "Setting up logging"
mkdir -p /var/log
touch /var/log/power_save.log
chmod 644 /var/log/power_save.log

# Install dependencies
log_step "Installing dependencies"
if command -v apt-get &> /dev/null; then
    # Debian/Ubuntu
    apt-get update
    apt-get install -y curl jq
elif command -v yum &> /dev/null; then
    # RHEL/CentOS
    yum install -y curl jq
elif command -v zypper &> /dev/null; then
    # SUSE
    zypper install -y curl jq
else
    log_error "Unsupported package manager"
fi

# Update SLURM configuration
log_step "Updating SLURM configuration"
SLURM_CONF="/etc/slurm/slurm.conf"
if [ -f "$SLURM_CONF" ]; then
    # Backup existing configuration
    cp "$SLURM_CONF" "${SLURM_CONF}.bak"
    
    # Update SLURM configuration
    sed -i "s|^SuspendProgram=.*|SuspendProgram=$INSTALL_DIR/scripts/slurm/suspend.sh|" "$SLURM_CONF"
    sed -i "s|^ResumeProgram=.*|ResumeProgram=$INSTALL_DIR/scripts/slurm/resume.sh|" "$SLURM_CONF"
    
    # Add power saving parameters if they don't exist
    grep -q "^SuspendTime=" "$SLURM_CONF" || echo "SuspendTime=300" >> "$SLURM_CONF"
    grep -q "^ResumeTimeout=" "$SLURM_CONF" || echo "ResumeTimeout=240" >> "$SLURM_CONF"
    grep -q "^SuspendTimeout=" "$SLURM_CONF" || echo "SuspendTimeout=300" >> "$SLURM_CONF"
    grep -q "^ResumeRate=" "$SLURM_CONF" || echo "ResumeRate=40" >> "$SLURM_CONF"
    grep -q "^SuspendRate=" "$SLURM_CONF" || echo "SuspendRate=40" >> "$SLURM_CONF"
    grep -q "^BatchStartTimeout=" "$SLURM_CONF" || echo "BatchStartTimeout=360" >> "$SLURM_CONF"
    grep -q "^MessageTimeout=" "$SLURM_CONF" || echo "MessageTimeout=100" >> "$SLURM_CONF"
fi

# Create environment file for Redfish credentials
log_step "Creating environment file"
cat > /etc/profile.d/redfish-power.sh << 'EOF'
# Redfish Power Management credentials
# Please update these values with your actual credentials
export REDFISH_USERNAME="root"
export REDFISH_PASSWORD="calvin"
export REDFISH_PORT="443"
EOF
chmod 644 /etc/profile.d/redfish-power.sh

log_step "Installation completed successfully!"
echo "Please:"
echo "1. Update Redfish credentials in /etc/profile.d/redfish-power.sh"
echo "2. Source the environment file: source /etc/profile.d/redfish-power.sh"
echo "3. Run 'scontrol reconfigure' to apply SLURM configuration changes"
echo "4. Test the installation with: $INSTALL_DIR/tests/test_power_management.sh <node-name>" 