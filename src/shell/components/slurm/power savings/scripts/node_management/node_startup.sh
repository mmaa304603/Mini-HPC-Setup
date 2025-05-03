#!/bin/bash

# Source configuration
CONFIG_DIR="$(dirname "$0")/../../config"
source "${CONFIG_DIR}/redfish.conf"

# Override config with environment variables if they exist
REDFISH_USERNAME=${REDFISH_USERNAME:-$REDFISH_USERNAME}
REDFISH_PASSWORD=${REDFISH_PASSWORD:-$REDFISH_PASSWORD}
REDFISH_PORT=${REDFISH_PORT:-$REDFISH_PORT}

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" >> "${LOG_FILE}"
}

# Function to check if a node is powered on
check_power_state() {
    local node=$1
    local state
    state=$(curl -s -k -u "${REDFISH_USERNAME}:${REDFISH_PASSWORD}" \
        "${REDFISH_BASE_URL}/Systems/${SYSTEM_ID}" | jq -r '.PowerState')
    if [ "$state" = "On" ]; then
        return 0
    else
        return 1
    fi
}

# Function to get system ID with retry
get_system_id() {
    local node=$1
    local retry_count=0
    local system_id

    while [ $retry_count -lt $MAX_RETRIES ]; do
        system_id=$(curl -s -k -u "${REDFISH_USERNAME}:${REDFISH_PASSWORD}" \
            "${REDFISH_BASE_URL}/Systems" | jq -r '.Members[0]["@odata.id"]' | cut -d'/' -f4)
        
        if [ -n "$system_id" ] && [ "$system_id" != "null" ]; then
            echo "$system_id"
            return 0
        fi
        
        retry_count=$((retry_count + 1))
        if [ $retry_count -lt $MAX_RETRIES ]; then
            log_message "Retry $retry_count: Failed to get system ID for $node"
            sleep $RETRY_DELAY
        fi
    done
    
    log_message "Error: Failed to get system ID for $node after $MAX_RETRIES attempts"
    return 1
}

# Main script
NODE=$1
REDFISH_BASE_URL="https://${NODE}:${REDFISH_PORT}/redfish/v1"

# Check if node parameter is provided
if [ -z "$NODE" ]; then
    log_message "Error: No node specified"
    exit 1
fi

# Get system ID
SYSTEM_ID=$(get_system_id "$NODE")
if [ $? -ne 0 ]; then
    exit 1
fi

# Check current power state
if check_power_state "$NODE"; then
    log_message "Node $NODE is already powered on"
    exit 0
fi

# Send power on command with retry
retry_count=0
while [ $retry_count -lt $MAX_RETRIES ]; do
    response=$(curl -s -k -w "%{http_code}" -X POST \
        -u "${REDFISH_USERNAME}:${REDFISH_PASSWORD}" \
        -H "Content-Type: application/json" \
        -d '{"ResetType": "On"}' \
        "${REDFISH_BASE_URL}/Systems/${SYSTEM_ID}/Actions/ComputerSystem.Reset")
    
    http_code=${response: -3}
    response_body=${response%???}
    
    if [ "$http_code" = "204" ] || [ "$http_code" = "200" ]; then
        log_message "Successfully sent power on command to $NODE"
        
        # Wait for power on
        sleep 30  # Give more time for power on
        if check_power_state "$NODE"; then
            log_message "Node $NODE is now powered on"
            exit 0
        else
            log_message "Warning: Node $NODE may not have powered on properly"
        fi
        break
    fi
    
    retry_count=$((retry_count + 1))
    if [ $retry_count -lt $MAX_RETRIES ]; then
        log_message "Retry $retry_count: Failed to power on $NODE (HTTP $http_code)"
        sleep $RETRY_DELAY
    fi
done

if [ $retry_count -eq $MAX_RETRIES ]; then
    log_message "Error: Failed to power on $NODE after $MAX_RETRIES attempts"
    exit 1
fi
