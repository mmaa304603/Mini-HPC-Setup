# Development Tools

This directory contains development tools for maintaining the Mini HPC cluster setup project. These tools are not part of the HPC cluster implementation but are used for project management and development.

## Purpose

The tools directory contains utilities for:
- Code quality assurance
- Development workflow automation
- Project maintenance
- Testing and validation

## Directory Structure

```
tools/
├── lint/         # Code quality tools
│   ├── shell/   # Shell script linters
│   └── ansible/ # Ansible linters
│
├── format/       # Code formatting tools
│   ├── shell/   # Shell script formatters
│   └── ansible/ # Ansible formatters
│
└── test/         # Test automation tools
    ├── unit/    # Unit test runners
    ├── integration/ # Integration test runners
    └── performance/ # Performance test runners
```

## Usage

### Code Quality
```bash
# Lint shell scripts
./tools/lint/shell/lint.sh

# Lint Ansible playbooks
./tools/lint/ansible/lint.sh
```

### Code Formatting
```bash
# Format shell scripts
./tools/format/shell/format.sh

# Format Ansible playbooks
./tools/format/ansible/format.sh
```

### Test Automation
```bash
# Run unit tests
./tools/test/unit/run-tests.sh

# Run integration tests
./tools/test/integration/run-tests.sh

# Run performance tests
./tools/test/performance/run-tests.sh
```

## Development Guidelines

### Adding New Tools
1. Place tool in appropriate subdirectory
2. Add documentation in tool's README
3. Update this README with tool information
4. Add tool to CI/CD pipeline

### Tool Requirements
- Must be self-contained
- Must include documentation
- Must include error handling
- Must support configuration
- Must be maintainable

## Integration with CI/CD

Tools are integrated into the CI/CD pipeline through `.gitlab-ci.yml`:
- Linting runs on every commit
- Formatting runs on pull requests
- Testing runs on merge requests

## Support

For tool-related issues:
- Email: hpc-dev@ttu.edu
- Documentation: `docs/development/tools.md`
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues) 