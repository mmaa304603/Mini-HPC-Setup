#!/bin/bash

# Ansible role unit tests

# Load test configuration
source ../../config/test_config.sh

# Logging setup
LOG_DIR="/var/log/tests/unit/ansible"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/$(date +%Y%m%d_%H%M%S).log"

# Test functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

run_test() {
    local role="$1"
    local test_name="$2"
    log "Running test: $test_name for role $role"
    if ansible-playbook -i ../../ansible/inventory/test_hosts.yml ../../ansible/roles/$role/tests/test.yml; then
        log "Test passed: $test_name"
        return 0
    else
        log "Test failed: $test_name"
        return 1
    fi
}

# Run tests
log "Starting Ansible role unit tests"

# Test init role
run_test "init" "Initial Setup"

# Test common role
run_test "common" "Common Configurations"

# Test network role
run_test "network" "Network Setup"

# Test warewulf role
run_test "warewulf" "Node Provisioning"

# Test slurm role
run_test "slurm" "SLURM Configuration"

# Test eraider role
run_test "eraider" "eRaider Authentication"

# Test globus role
run_test "globus" "Globus Setup"

# Test spack role
run_test "spack" "Spack Configuration"

# Test squid role - removed, no longer needed with spack
# run_test "squid" "Squid Proxy"

# Test elk role
run_test "elk" "ELK Stack"

# Test grafana role
run_test "grafana" "Grafana Dashboards"

# Test backup role
run_test "backup" "Backup Management"

# Test security role
run_test "security" "Security Configuration"

# Test maintenance role
run_test "maintenance" "Maintenance Tasks"

log "Ansible role unit tests completed"
exit 0 