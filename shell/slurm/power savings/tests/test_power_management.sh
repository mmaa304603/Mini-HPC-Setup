#!/bin/bash

# Test script for SLURM power management with Redfish
# This script tests the basic functionality of node power management

# Source the configuration
CONFIG_DIR="$(dirname "$0")/../config"
source "${CONFIG_DIR}/redfish.conf"

# Test node (should be provided as argument)
TEST_NODE=$1

if [ -z "$TEST_NODE" ]; then
    echo "Error: Please provide a test node name"
    echo "Usage: $0 <node_name>"
    exit 1
fi

# Function to log test results
log_test() {
    local test_name=$1
    local result=$2
    local message=$3
    
    if [ "$result" = "PASS" ]; then
        echo -e "\033[32m[PASS]\033[0m $test_name: $message"
    else
        echo -e "\033[31m[FAIL]\033[0m $test_name: $message"
    fi
}

# Test 1: Check if node_shutdown.sh exists and is executable
if [ -x "$(dirname "$0")/../scripts/node_management/node_shutdown.sh" ]; then
    log_test "Script Check" "PASS" "node_shutdown.sh is present and executable"
else
    log_test "Script Check" "FAIL" "node_shutdown.sh is missing or not executable"
    exit 1
fi

# Test 2: Check if node_startup.sh exists and is executable
if [ -x "$(dirname "$0")/../scripts/node_management/node_startup.sh" ]; then
    log_test "Script Check" "PASS" "node_startup.sh is present and executable"
else
    log_test "Script Check" "FAIL" "node_startup.sh is missing or not executable"
    exit 1
fi

# Test 3: Check Redfish connectivity
echo "Testing Redfish connectivity to $TEST_NODE..."
if curl -s -k -u "${REDFISH_USERNAME}:${REDFISH_PASSWORD}" \
    "https://${TEST_NODE}:${REDFISH_PORT}/redfish/v1/Systems" > /dev/null; then
    log_test "Redfish Connectivity" "PASS" "Successfully connected to Redfish API"
else
    log_test "Redfish Connectivity" "FAIL" "Could not connect to Redfish API"
    exit 1
fi

# Test 4: Power off node
echo "Testing power off functionality..."
if "$(dirname "$0")/../scripts/node_management/node_shutdown.sh" "$TEST_NODE"; then
    log_test "Power Off" "PASS" "Successfully powered off node"
else
    log_test "Power Off" "FAIL" "Failed to power off node"
    exit 1
fi

# Wait for node to power off
sleep 30

# Test 5: Power on node
echo "Testing power on functionality..."
if "$(dirname "$0")/../scripts/node_management/node_startup.sh" "$TEST_NODE"; then
    log_test "Power On" "PASS" "Successfully powered on node"
else
    log_test "Power On" "FAIL" "Failed to power on node"
    exit 1
fi

# Wait for node to power on
sleep 60

# Test 6: Check if node is responsive
echo "Testing node responsiveness..."
if ping -c 1 "$TEST_NODE" > /dev/null; then
    log_test "Node Responsiveness" "PASS" "Node is responsive after power cycle"
else
    log_test "Node Responsiveness" "FAIL" "Node is not responsive after power cycle"
    exit 1
fi

echo "All tests completed successfully!" 