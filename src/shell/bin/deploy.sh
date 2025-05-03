#!/bin/bash

# Deployment Automation Script
# Version: 1.0.0

# Configuration
SCRIPT_DIR="$(dirname "$0")"
LOG_FILE="$SCRIPT_DIR/../logs/deploy.log"
CONFIG_FILE="$SCRIPT_DIR/../config/deploy.conf"
INVENTORY_FILE="$SCRIPT_DIR/../config/inventory.yml"

# Logging setup
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Error handling
handle_error() {
    log "ERROR: $1"
    exit 1
}

# Validate environment
validate_environment() {
    log "Validating environment..."
    
    # Check for required commands
    for cmd in ansible ssh-keygen ssh-copy-id; do
        if ! command -v $cmd &> /dev/null; then
            handle_error "$cmd is required but not installed"
        fi
    done
    
    # Check for required files
    for file in "$CONFIG_FILE" "$INVENTORY_FILE"; do
        if [ ! -f "$file" ]; then
            handle_error "Missing required file: $file"
        fi
    done
}

# Setup SSH keys
setup_ssh_keys() {
    log "Setting up SSH keys..."
    
    # Generate SSH key if not exists
    if [ ! -f ~/.ssh/id_rsa ]; then
        ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N "" || handle_error "Failed to generate SSH key"
    fi
    
    # Copy SSH key to target hosts
    while read -r host; do
        ssh-copy-id -i ~/.ssh/id_rsa.pub "$host" || handle_error "Failed to copy SSH key to $host"
    done < <(ansible-inventory -i "$INVENTORY_FILE" --list | jq -r '.all.hosts[]')
}

# Run pre-deployment checks
pre_deployment_checks() {
    log "Running pre-deployment checks..."
    
    # Check system requirements
    ansible-playbook -i "$INVENTORY_FILE" "$SCRIPT_DIR/../ansible/playbooks/pre-deploy.yml" || handle_error "Pre-deployment checks failed"
    
    # Check disk space
    ansible all -i "$INVENTORY_FILE" -m shell -a "df -h" || handle_error "Failed to check disk space"
    
    # Check network connectivity
    ansible all -i "$INVENTORY_FILE" -m ping || handle_error "Failed to check network connectivity"
}

# Deploy components
deploy_components() {
    log "Deploying components..."
    
    # Deploy base system
    ansible-playbook -i "$INVENTORY_FILE" "$SCRIPT_DIR/../ansible/playbooks/base.yml" || handle_error "Failed to deploy base system"
    
    # Deploy services
    ansible-playbook -i "$INVENTORY_FILE" "$SCRIPT_DIR/../ansible/playbooks/services.yml" || handle_error "Failed to deploy services"
    
    # Deploy applications
    ansible-playbook -i "$INVENTORY_FILE" "$SCRIPT_DIR/../ansible/playbooks/applications.yml" || handle_error "Failed to deploy applications"
}

# Verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    # Run post-deployment checks
    ansible-playbook -i "$INVENTORY_FILE" "$SCRIPT_DIR/../ansible/playbooks/post-deploy.yml" || handle_error "Post-deployment checks failed"
    
    # Check service status
    ansible all -i "$INVENTORY_FILE" -m shell -a "systemctl status" || handle_error "Failed to check service status"
}

# Main function
main() {
    log "Starting deployment"
    
    # Validate environment
    validate_environment
    
    # Setup SSH keys
    setup_ssh_keys
    
    # Run pre-deployment checks
    pre_deployment_checks
    
    # Deploy components
    deploy_components
    
    # Verify deployment
    verify_deployment
    
    log "Deployment completed successfully"
}

# Execute main function
main "$@" 