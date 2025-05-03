# Test Framework

This directory contains the test framework for the Mini HPC cluster setup. Tests are organized by type and cover both Ansible and shell-based configurations.

## Directory Structure

```
tests/
├── unit/              # Unit tests
│   ├── ansible/      # Ansible role tests
│   └── shell/        # Shell script tests
│
├── integration/       # Integration tests
│   ├── ansible/      # Ansible playbook tests
│   └── shell/        # Shell integration tests
│
├── performance/       # Performance tests
│   ├── ansible/      # Ansible performance tests
│   └── shell/        # Shell performance tests
│
└── data/             # Test data
    ├── ansible/      # Ansible test data
    └── shell/        # Shell test data
```

## Test Types

### Unit Tests
- Test individual components in isolation
- Located in `tests/unit/`
- Focus on:
  - Ansible roles
  - Shell script functions
  - Configuration templates

### Integration Tests
- Test component interactions
- Located in `tests/integration/`
- Focus on:
  - Ansible playbooks
  - Shell script workflows
  - System configurations

### Performance Tests
- Test system performance
- Located in `tests/performance/`
- Focus on:
  - Resource utilization
  - Response times
  - Throughput

### Test Data
- Data used for testing
- Located in `tests/data/`
- Includes:
  - Sample configurations
  - Test inputs
  - Expected outputs

## Running Tests

### All Tests
```bash
./run-tests.sh
```

### Specific Test Types
```bash
# Unit tests
./run-tests.sh unit

# Integration tests
./run-tests.sh integration

# Performance tests
./run-tests.sh performance
```

## Test Data

The `tests/data/` directory contains:
- Sample configurations
- Test inputs
- Expected outputs
- Performance baselines

## Support

For test-related issues:
- Email: hpc-test@ttu.edu
- Documentation: `src/common/docs/development/testing.md`
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues) 