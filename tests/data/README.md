# Test Data

This directory contains test data used for various types of tests in the Mini HPC cluster setup.

## Directory Structure

```
tests/data/
├── ansible/          # Ansible test data
│   ├── roles/       # Role-specific test data
│   ├── playbooks/   # Playbook test data
│   └── inventory/   # Inventory test data
│
├── shell/           # Shell script test data
│   ├── bin/        # Executable test data
│   ├── config/     # Configuration test data
│   └── templates/  # Template test data
│
├── sample_configs/  # Sample configuration files
│   ├── network/    # Network configurations
│   ├── services/   # Service configurations
│   └── security/   # Security configurations
│
└── test_data/      # Generated test data
    ├── storage/    # Storage test data
    ├── performance/ # Performance test data
    └── network/    # Network test data
```

## Usage

### Ansible Test Data
- Located in `ansible/`
- Used for testing Ansible roles and playbooks
- Includes sample inventories and variables

### Shell Test Data
- Located in `shell/`
- Used for testing shell scripts
- Includes sample configurations and templates

### Sample Configurations
- Located in `sample_configs/`
- Example configurations for different components
- Used for testing and documentation

### Generated Test Data
- Located in `test_data/`
- Dynamically generated test data
- Used for performance and integration testing

## Generating Test Data

### Storage Test Data
```bash
cd tests/data/test_data/storage
./storage_test_data.sh
```

### Performance Test Data
```bash
cd tests/data/test_data/performance
./performance_test_data.sh
```

## Support

For test data issues:
- Email: hpc-test@ttu.edu
- Documentation: `src/common/docs/development/testing.md`
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues) 