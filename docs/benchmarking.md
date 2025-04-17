# HPC Benchmarking

This document provides detailed information about the benchmarking setup and configuration for the HPC cluster.

## Overview

The benchmarking system uses GitLab CI to automate the execution of standard HPC benchmarks. The results are automatically collected and sent to a Microsoft Teams channel for easy monitoring.

## Benchmarks

### HPL (High Performance Linpack)

HPL is a portable implementation of the High Performance Computing Linpack Benchmark.

#### Configuration
- **Nodes**: 3
- **Tasks per Node**: 4
- **Time Limit**: 1 hour
- **Partition**: normal

#### Command
```bash
srun --partition=normal --nodes=3 --ntasks-per-node=4 --time=01:00:00 hpl
```

### OSU Micro-Benchmarks

The OSU Micro-Benchmarks suite measures the performance of various MPI operations.

#### Configuration
- **Nodes**: 2
- **Tasks per Node**: 2
- **Time Limit**: 30 minutes per test
- **Partition**: normal
- **Tests**: allreduce, bcast, alltoall

#### Commands
```bash
srun --partition=normal --nodes=2 --ntasks-per-node=2 --time=00:30:00 osu_allreduce
srun --partition=normal --nodes=2 --ntasks-per-node=2 --time=00:30:00 osu_bcast
srun --partition=normal --nodes=2 --ntasks-per-node=2 --time=00:30:00 osu_alltoall
```

### STREAM

STREAM is a simple synthetic benchmark program that measures sustainable memory bandwidth.

#### Configuration
- **Nodes**: 3
- **Tasks per Node**: 1
- **Time Limit**: 30 minutes
- **Partition**: normal

#### Command
```bash
srun --partition=normal --nodes=3 --ntasks-per-node=1 --time=00:30:00 stream
```

## GitLab CI Configuration

The benchmarking pipeline is defined in `.gitlab-ci.yml`:

```yaml
stages:
  - benchmark

variables:
  SLURM_CLUSTER: hpc-cluster
  TEAMS_WEBHOOK_URL: ${TEAMS_WEBHOOK_URL}

benchmark:
  stage: benchmark
  script:
    - |
      #!/bin/bash
      
      # Load required modules
      module load openmpi
      module load hpl
      module load osu-micro-benchmarks
      module load stream
      
      # Run benchmarks
      # ... (benchmark commands)
      
      # Send results to Microsoft Teams
      curl -H "Content-Type: application/json" -d "{
        \"@type\": \"MessageCard\",
        \"@context\": \"http://schema.org/extensions\",
        \"themeColor\": \"0072C6\",
        \"summary\": \"HPC Benchmark Results\",
        \"sections\": [{
          \"activityTitle\": \"HPC Benchmark Results\",
          \"activitySubtitle\": \"Benchmark run completed on $(date)\",
          \"facts\": [{
            \"name\": \"Status\",
            \"value\": \"Completed\"
          }]
        }]
      }" $TEAMS_WEBHOOK_URL
  rules:
    - if: $CI_PIPELINE_SOURCE == "schedule"
    - if: $CI_PIPELINE_SOURCE == "web"
  tags:
    - hpc
```

## Setup Requirements

### GitLab Runner

1. Install GitLab Runner on the head node:
   ```bash
   curl -L https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.rpm.sh | sudo bash
   sudo yum install gitlab-runner
   ```

2. Register the runner with the 'hpc' tag:
   ```bash
   sudo gitlab-runner register
   # Select "shell" executor
   # Add "hpc" tag
   ```

3. Start the runner:
   ```bash
   sudo systemctl enable gitlab-runner
   sudo systemctl start gitlab-runner
   ```

### Required Software

Install the required benchmark software using Spack:

```bash
# Load Spack
source /etc/profile.d/spack.sh

# Install benchmarks
spack install hpl
spack install osu-micro-benchmarks
spack install stream

# Create module files
spack module tcl refresh
```

### Microsoft Teams Integration

1. Create a webhook in Microsoft Teams:
   - Go to the channel where you want to receive notifications
   - Click the "..." menu and select "Connectors"
   - Find "Incoming Webhook" and click "Configure"
   - Give it a name and click "Create"
   - Copy the webhook URL

2. Add the webhook URL to GitLab CI/CD variables:
   - Go to your GitLab project
   - Navigate to Settings > CI/CD > Variables
   - Add a variable named `TEAMS_WEBHOOK_URL` with the webhook URL
   - Mark it as "Masked" and "Protected"

## Scheduling

The benchmarks can be scheduled to run automatically:

1. Go to your GitLab project
2. Navigate to CI/CD > Schedules
3. Click "New schedule"
4. Set the schedule (e.g., weekly on Sunday at 2 AM)
5. Select the branch to run on (usually main)
6. Click "Create schedule"

## Manual Execution

To run the benchmarks manually:

1. Go to your GitLab project
2. Navigate to CI/CD > Pipelines
3. Click "Run pipeline"
4. Select the branch to run on
5. Click "Run pipeline"

## Troubleshooting

### Common Issues

1. **GitLab Runner not connecting to SLURM**
   - Ensure the runner is running on the head node
   - Check that the 'hpc' tag is correctly set
   - Verify SLURM is running: `systemctl status slurmctld`

2. **Benchmarks failing to start**
   - Check that all required modules are available: `module avail`
   - Verify SLURM partitions are correctly configured: `sinfo`
   - Check SLURM logs: `tail -f /var/log/slurm/slurm_jobacct.log`

3. **Results not sent to Teams**
   - Verify the webhook URL is correctly set in GitLab CI/CD variables
   - Check that the webhook is still active in Teams
   - Look for errors in the GitLab CI job logs

### Logs

- GitLab Runner logs: `journalctl -u gitlab-runner`
- SLURM logs: `/var/log/slurm/`
- GitLab CI job logs: Available in the GitLab web interface 