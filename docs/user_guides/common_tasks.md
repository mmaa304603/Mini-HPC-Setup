# Common Tasks Guide

## Job Submission

### Basic Job Submission
```bash
# Submit a simple job
sbatch job.sh

# Submit with specific resources
sbatch --nodes=2 --ntasks-per-node=4 --mem=8G job.sh

# Submit with GPU
sbatch --gres=gpu:1 job.sh
```

### Job Management
```bash
# Check job status
squeue

# Cancel a job
scancel <job_id>

# Hold a job
scontrol hold <job_id>

# Release a held job
scontrol release <job_id>
```

## File Transfer

### Using Globus
```bash
# Check endpoint status
globus endpoint show HPC\ Cluster

# Transfer files
globus transfer <source_endpoint>:<path> <dest_endpoint>:<path>

# Monitor transfer
globus task show <task_id>
```

### Using scp
```bash
# Copy file to cluster
scp file.txt user@cluster:/path/to/destination

# Copy directory
scp -r directory user@cluster:/path/to/destination

# Copy from cluster
scp user@cluster:/path/to/file.txt .
```

## Software Management

### Using Spack
```bash
# Search for packages
spack list <package_name>

# Install package
spack install <package_name>

# Load package
spack load <package_name>
```

### Using Apptainer
```bash
# Pull container
apptainer pull docker://<image>

# Run container
apptainer exec <image> <command>

# Build container
apptainer build <image> <definition_file>
```

## Data Management

### Check Quota
```bash
# Check home directory quota
quota -s

# Check scratch space
df -h /scratch
```

### Clean Up
```bash
# Find large files
find /home -type f -size +1G -exec ls -lh {} \;

# Remove old files
find /scratch -type f -mtime +30 -delete
```

## Troubleshooting

### Common Issues
```bash
# Check job status
squeue -u $USER

# Check job output
cat slurm-<job_id>.out

# Check error messages
cat slurm-<job_id>.err
```

### Getting Help
```bash
# Check documentation
man <command>

# Contact support
support@ttu.edu
``` 