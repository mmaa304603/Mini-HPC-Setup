# SLURM Power Saving with Redfish
## Example Scripts

The files in this repository provide examples for implementing SLURM's Power Saving feature using Redfish for node power management. This implementation replaces the traditional IPMI/WoL approach with a more modern and standardized Redfish API.

## Prerequisites

1. **Redfish Support**:
   - Ensure your compute nodes' BMC/iDRAC/iLO support Redfish API
   - Redfish should be enabled in your BMC settings
   - Verify Redfish endpoints are accessible from your management node

2. **Required Software**:
   ```bash
   # For RHEL/CentOS
   sudo yum install curl jq
   
   # For Ubuntu/Debian
   sudo apt-get install curl jq
   ```

## Configuration

1. **Redfish Credentials**:
   - Edit `redfish.conf` to set your Redfish credentials
   - For better security, use environment variables:
     ```bash
     export REDFISH_USERNAME="your_username"
     export REDFISH_PASSWORD="your_password"
     export REDFISH_PORT="443"  # or your custom port
     ```

2. **SLURM Configuration**:
   - Edit `slurm.conf` to set appropriate timeouts:
     ```bash
     SuspendTime=300      # 5 minutes
     SuspendRate=40       # Nodes to stop at once
     ResumeRate=40        # Nodes to start at once
     SuspendTimeout=300   # Shutdown timeout
     ResumeTimeout=240    # Startup timeout
     ```
   - Set node STATE=CLOUD for suspendable nodes
   - Configure SuspendProgram and ResumeProgram paths

## Implementation Details

The implementation consists of several components:

1. **Configuration File** (`redfish.conf`):
   - Centralizes Redfish settings
   - Configurable retry attempts and delays
   - Logging configuration

2. **Node Management Scripts**:
   - `node_shutdown.sh`: Powers off nodes using Redfish
   - `node_startup.sh`: Powers on nodes using Redfish
   - Both scripts include:
     - Error handling and retry logic
     - Power state verification
     - Detailed logging
     - Environment variable support

3. **SLURM Integration**:
   - `suspend.sh`: SLURM suspend program
   - `resume.sh`: SLURM resume program

## Testing

Before deploying to production:

1. Test power management:
   ```bash
   # Test power off
   ./node_shutdown.sh your-node-name
   
   # Test power on
   ./node_startup.sh your-node-name
   ```

2. Check logs:
   ```bash
   tail -f /var/log/power_save.log
   ```

## Troubleshooting

1. **Common Issues**:
   - Redfish endpoint not accessible: Check network connectivity and BMC settings
   - Authentication failures: Verify credentials in redfish.conf or environment variables
   - Power state changes not detected: Adjust sleep timers in scripts

2. **Logging**:
   - All operations are logged to `/var/log/power_save.log`
   - Check logs for detailed error messages and retry attempts

## SLURM Node States

Remember the sinfo codes:
- `*` Node not responding
- `~` Node powered off
- `#` Node powering up
- `!` Node pending power down
- `%` Node powering down
- `$` Node in maintenance reservation
- `@` Node pending reboot
- `^` Node reboot issued
- `-` Node planned for higher priority job

## Security Considerations

1. **Credential Management**:
   - Use environment variables for sensitive data
   - Consider using a secure credential store
   - Implement proper access controls for configuration files

2. **Network Security**:
   - Use HTTPS for Redfish communication
   - Implement proper network segmentation
   - Consider using certificates for authentication

## Maintenance

1. **Regular Tasks**:
   - Monitor power_save.log for issues
   - Verify node power states periodically
   - Update credentials as needed
   - Test power management functionality after system updates

2. **Updates**:
   - Keep track of Redfish API changes
   - Update scripts for new Redfish features
   - Test thoroughly before deploying updates

To Do:
1. Test on SUSE
2. Test IPMI
3. ?
