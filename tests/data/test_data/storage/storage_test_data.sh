#!/bin/bash

# Storage Test Data Generator
# Version: 1.0.0

# Configuration
DATA_DIR="$(dirname "$0")"
OUTPUT_DIR="$DATA_DIR/output"
LOG_FILE="$DATA_DIR/storage_test_data.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Generate storage configuration data
generate_config() {
    log "Generating storage configuration data..."
    cat > "$OUTPUT_DIR/config.json" << EOF
{
    "storage_systems": [
        {
            "id": "hpss-1",
            "type": "high_performance",
            "capacity": "100TB",
            "filesystem": "lustre",
            "nodes": ["compute-1", "compute-2"]
        },
        {
            "id": "capacity-1",
            "type": "capacity",
            "capacity": "1PB",
            "filesystem": "ceph",
            "nodes": ["compute-3", "compute-4"]
        }
    ]
}
EOF
    log "Storage configuration data generated"
}

# Generate storage performance data
generate_performance() {
    log "Generating storage performance data..."
    cat > "$OUTPUT_DIR/performance.json" << EOF
{
    "hpss-1": {
        "iops": {
            "read": 100000,
            "write": 80000
        },
        "throughput": {
            "read": "10GB/s",
            "write": "8GB/s"
        },
        "latency": {
            "read": "50us",
            "write": "60us"
        }
    },
    "capacity-1": {
        "iops": {
            "read": 50000,
            "write": 40000
        },
        "throughput": {
            "read": "5GB/s",
            "write": "4GB/s"
        },
        "latency": {
            "read": "100us",
            "write": "120us"
        }
    }
}
EOF
    log "Storage performance data generated"
}

# Generate storage usage data
generate_usage() {
    log "Generating storage usage data..."
    cat > "$OUTPUT_DIR/usage.csv" << EOF
timestamp,system,used,available,utilization
$(date -d "1 day ago" +%s),hpss-1,50TB,50TB,50%
$(date -d "1 day ago" +%s),capacity-1,500TB,500TB,50%
$(date +%s),hpss-1,60TB,40TB,60%
$(date +%s),capacity-1,600TB,400TB,60%
EOF
    log "Storage usage data generated"
}

# Main function
main() {
    log "Starting storage test data generation"
    generate_config
    generate_performance
    generate_usage
    log "Storage test data generation completed"
}

# Run main function
main 