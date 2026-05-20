#!/bin/bash

# HPC Management Wrapper Script

# Load configuration
source /etc/hpc/config.conf

# Logging function
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_DIR/hpc_manage.log"
}

# Error handling
error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - ERROR: $1" | tee -a "$LOG_DIR/hpc_manage.error.log"
    exit 1
}

# Check system status
check_system() {
    log "Checking system status..."
    
    # Check services
    systemctl status warewulfd >/dev/null 2>&1 || error "Warewulf service not running"
    systemctl status slurmctld >/dev/null 2>&1 || error "SLURM controller not running"
    systemctl status globus-connect-server >/dev/null 2>&1 || error "Globus service not running"
    
    # Check disk space
    df -h | grep -q "$HOME_DIR" || error "Home directory not mounted"
    df -h | grep -q "$SHARED_DIR" || error "Shared directory not mounted"
    df -h | grep -q "$SCRATCH_DIR" || error "Scratch directory not mounted"
    
    log "System status check completed successfully"
}

# Manage users
manage_users() {
    case "$1" in
        add)
            log "Adding user: $2"
            useradd -m -s /bin/bash "$2" || error "Failed to add user"
            ;;
        remove)
            log "Removing user: $2"
            userdel -r "$2" || error "Failed to remove user"
            ;;
        list)
            log "Listing users"
            getent passwd | grep -v nologin
            ;;
        *)
            error "Invalid user operation: $1"
            ;;
    esac
}

# Manage jobs
manage_jobs() {
    case "$1" in
        list)
            log "Listing jobs"
            squeue
            ;;
        cancel)
            log "Canceling job: $2"
            scancel "$2" || error "Failed to cancel job"
            ;;
        hold)
            log "Holding job: $2"
            scontrol hold "$2" || error "Failed to hold job"
            ;;
        release)
            log "Releasing job: $2"
            scontrol release "$2" || error "Failed to release job"
            ;;
        *)
            error "Invalid job operation: $1"
            ;;
    esac
}

# Manage backups
manage_backups() {
    case "$1" in
        create)
            log "Creating backup"
            /usr/local/bin/backup_config.sh || error "Backup failed"
            ;;
        restore)
            log "Restoring backup: $2"
            /usr/local/bin/restore_config.sh "$2" || error "Restore failed"
            ;;
        list)
            log "Listing backups"
            ls -la "$BACKUP_DIR"
            ;;
        *)
            error "Invalid backup operation: $1"
            ;;
    esac
}

# Main function
main() {
    case "$1" in
        check)
            check_system
            ;;
        user)
            manage_users "$2" "$3"
            ;;
        job)
            manage_jobs "$2" "$3"
            ;;
        backup)
            manage_backups "$2" "$3"
            ;;
        *)
            echo "Usage: $0 {check|user|job|backup} [operation] [argument]"
            exit 1
            ;;
    esac
}

# Execute main function
main "$@" 