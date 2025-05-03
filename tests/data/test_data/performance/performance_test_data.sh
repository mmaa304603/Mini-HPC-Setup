#!/bin/bash

# Performance Test Data Generator
# Version: 1.0.0

# Configuration
DATA_DIR="$(dirname "$0")"
OUTPUT_DIR="$DATA_DIR/output"
LOG_FILE="$DATA_DIR/performance_test_data.log"

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Generate CPU performance data
generate_cpu() {
    log "Generating CPU performance data..."
    cat > "$OUTPUT_DIR/cpu.json" << EOF
{
    "head-node": {
        "utilization": {
            "min": 20,
            "max": 80,
            "avg": 50
        },
        "load": {
            "1min": 2.5,
            "5min": 2.0,
            "15min": 1.8
        }
    },
    "compute-nodes": {
        "utilization": {
            "min": 30,
            "max": 90,
            "avg": 60
        },
        "load": {
            "1min": 3.0,
            "5min": 2.5,
            "15min": 2.2
        }
    }
}
EOF
    log "CPU performance data generated"
}

# Generate memory performance data
generate_memory() {
    log "Generating memory performance data..."
    cat > "$OUTPUT_DIR/memory.json" << EOF
{
    "head-node": {
        "total": "256GB",
        "used": "128GB",
        "free": "128GB",
        "utilization": 50
    },
    "compute-nodes": {
        "total": "512GB",
        "used": "384GB",
        "free": "128GB",
        "utilization": 75
    }
}
EOF
    log "Memory performance data generated"
}

# Generate job performance data
generate_jobs() {
    log "Generating job performance data..."
    cat > "$OUTPUT_DIR/jobs.csv" << EOF
job_id,user,nodes,cpus,memory,walltime,start_time,end_time,status
1001,user1,2,32,64GB,24:00:00,$(date -d "1 day ago" +%s),$(date +%s),COMPLETED
1002,user2,4,64,128GB,48:00:00,$(date -d "12 hours ago" +%s),,RUNNING
1003,user3,1,16,32GB,12:00:00,,,PENDING
EOF
    log "Job performance data generated"
}

# Main function
main() {
    log "Starting performance test data generation"
    generate_cpu
    generate_memory
    generate_jobs
    log "Performance test data generation completed"
}

# Run main function
main 