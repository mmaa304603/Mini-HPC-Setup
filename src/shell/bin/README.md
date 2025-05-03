# Executable Scripts

This directory contains executable scripts for managing the HPC cluster.

## Scripts

### Core Scripts
- `hpc-manage` - Main cluster management script
- `hpc-monitor` - Cluster monitoring script
- `hpc-backup` - Backup management script
- `hpc-security` - Security management script
- `hpc-test` - Testing and validation script

### Setup Scripts
- `setup-dev-env.sh` - Setup development environment
- `build.sh` - Build cluster components
- `deploy.sh` - Deploy cluster components
- `cleanup.sh` - Cleanup cluster components

## Usage

```bash
# Manage cluster
./hpc-manage [command] [options]

# Monitor cluster
./hpc-monitor [options]

# Backup cluster
./hpc-backup [options]

# Security management
./hpc-security [command] [options]

# Test cluster
./hpc-test [options]
```

## Dependencies

- Common utilities from `src/common/utils/`
- Library scripts from `src/shell/lib/`
- Configuration from `src/shell/config/`

## Support

For executable script issues:
- Email: hpc-dev@ttu.edu
- Documentation: `docs/development/bin.md`
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues) 