#!/bin/bash

# Comprehensive test suite for SLURM power management with Redfish
# This script runs a series of tests to verify the functionality of the power management system

# Source the configuration
CONFIG_DIR="$(dirname "$0")/../config"
source "${CONFIG_DIR}/redfish.conf"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test results counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Function to log test results
log_test() {
    local test_name=$1
    local result=$2
    local message=$3
    
    case "$result" in
        "PASS")
            echo -e "${GREEN}[PASS]${NC} $test_name: $message"
            TESTS_PASSED=$((TESTS_PASSED + 1))
            ;;
        "FAIL")
            echo -e "${RED}[FAIL]${NC} $test_name: $message"
            TESTS_FAILED=$((TESTS_FAILED + 1))
            ;;
        "SKIP")
            echo -e "${YELLOW}[SKIP]${NC} $test_name: $message"
            TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
            ;;
    esac
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Redfish endpoint health
check_redfish_health() {
    local node=$1
    local endpoint="https://${node}:${REDFISH_PORT}/redfish/v1/Systems"
    
    # Test basic connectivity
    if ! curl -s -k -u "${REDFISH_USERNAME}:${REDFISH_PASSWORD}" "$endpoint" > /dev/null; then
        return 1
    fi
    
    # Test authentication
    local http_code=$(curl -s -k -w "%{http_code}" -o /dev/null \
        -u "${REDFISH_USERNAME}:${REDFISH_PASSWORD}" "$endpoint")
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "204" ]; then
        return 0
    else
        return 1
    fi
}

# Function to verify SLURM configuration
check_slurm_config() {
    local config_file="/etc/slurm/slurm.conf"
    
    if [ ! -f "$config_file" ]; then
        return 1
    fi
    
    # Check for required parameters
    local required_params=(
        "SuspendProgram"
        "ResumeProgram"
        "SuspendTime"
        "ResumeTimeout"
        "SuspendTimeout"
    )
    
    for param in "${required_params[@]}"; do
        if ! grep -q "^${param}=" "$config_file"; then
            return 1
        fi
    done
    
    return 0
}

# Function to test node power state
test_power_state() {
    local node=$1
    local expected_state=$2
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        local state=$(curl -s -k -u "${REDFISH_USERNAME}:${REDFISH_PASSWORD}" \
            "https://${node}:${REDFISH_PORT}/redfish/v1/Systems/1" | \
            jq -r '.PowerState')
        
        if [ "$state" = "$expected_state" ]; then
            return 0
        fi
        
        sleep 5
        attempt=$((attempt + 1))
    done
    
    return 1
}

# Begin test suite
echo "Starting SLURM Power Management Test Suite..."
echo "============================================"

# Test 1: Check dependencies
echo -e "\nTesting Dependencies..."
for cmd in curl jq scontrol; do
    if command_exists "$cmd"; then
        log_test "Dependency Check" "PASS" "$cmd is installed"
    else
        log_test "Dependency Check" "FAIL" "$cmd is not installed"
        exit 1
    fi
done

# Test 2: Check SLURM configuration
echo -e "\nTesting SLURM Configuration..."
if check_slurm_config; then
    log_test "SLURM Config" "PASS" "SLURM configuration is properly set up"
else
    log_test "SLURM Config" "FAIL" "SLURM configuration is incomplete"
    exit 1
fi

# Test 3: Check script permissions
echo -e "\nTesting Script Permissions..."
for script in ../scripts/{node_management,slurm}/*.sh; do
    if [ -x "$script" ]; then
        log_test "Script Permissions" "PASS" "$(basename "$script") is executable"
    else
        log_test "Script Permissions" "FAIL" "$(basename "$script") is not executable"
        exit 1
    fi
done

# Test 4: Test node power management
echo -e "\nTesting Node Power Management..."
if [ -z "$1" ]; then
    log_test "Power Management" "SKIP" "No test node specified. Usage: $0 <node-name>"
else
    TEST_NODE=$1
    
    # Test 4.1: Check Redfish connectivity
    if check_redfish_health "$TEST_NODE"; then
        log_test "Redfish Connectivity" "PASS" "Successfully connected to $TEST_NODE"
        
        # Test 4.2: Power cycle test
        echo "Starting power cycle test..."
        
        # Power off
        if "$(dirname "$0")/../scripts/node_management/node_shutdown.sh" "$TEST_NODE"; then
            log_test "Power Off" "PASS" "Successfully powered off $TEST_NODE"
            
            # Verify power state
            if test_power_state "$TEST_NODE" "Off"; then
                log_test "Power State Verification" "PASS" "Node is confirmed to be powered off"
                
                # Power on
                if "$(dirname "$0")/../scripts/node_management/node_startup.sh" "$TEST_NODE"; then
                    log_test "Power On" "PASS" "Successfully powered on $TEST_NODE"
                    
                    # Verify power state
                    if test_power_state "$TEST_NODE" "On"; then
                        log_test "Power State Verification" "PASS" "Node is confirmed to be powered on"
                    else
                        log_test "Power State Verification" "FAIL" "Node failed to power on"
                    fi
                else
                    log_test "Power On" "FAIL" "Failed to power on $TEST_NODE"
                fi
            else
                log_test "Power State Verification" "FAIL" "Node failed to power off"
            fi
        else
            log_test "Power Off" "FAIL" "Failed to power off $TEST_NODE"
        fi
    else
        log_test "Redfish Connectivity" "FAIL" "Could not connect to $TEST_NODE"
    fi
fi

# Test 5: Check logging
echo -e "\nTesting Logging..."
if [ -f "/var/log/power_save.log" ] && [ -w "/var/log/power_save.log" ]; then
    log_test "Logging" "PASS" "Log file exists and is writable"
else
    log_test "Logging" "FAIL" "Log file issues detected"
fi

# Print test summary
echo -e "\nTest Summary"
echo "============"
echo "Tests Passed: $TESTS_PASSED"
echo "Tests Failed: $TESTS_FAILED"
echo "Tests Skipped: $TESTS_SKIPPED"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED + TESTS_SKIPPED))"

# Exit with appropriate status code
if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All tests completed successfully!${NC}"
    exit 0
else
    echo -e "\n${RED}Some tests failed. Please check the output above.${NC}"
    exit 1
fi 