# Mini HPC Cluster Setup

This project provides tools and documentation for setting up a Mini HPC cluster using either Ansible or shell scripts.

## Architecture Overview

The Mini cluster has the following architecture:
1. **Head Node**: One Radxa X2L with 2TB SSD
2. **CPU Compute Nodes**: Three Radxa X2L without external storage
3. **GPU Compute Node**: One Jetson Orin Nano with 512GB SSD (OS pre-flashed using Nvidia SDK manager)

## Network Configuration

Only the head node is connected to the public network. All compute nodes are connected through an internal switch with traffic routed through the head node:

- **Head Node Private IP**: 10.0.0.1
- **Subnet Mask**: 255.255.252.0 (10.0.0.0/22)
- **DHCP Range**: 10.0.1.1 - 10.0.1.3 (for PXE booting CPU compute nodes)
- **Static Node Addresses**: 
  - 10.0.2.1 - 10.0.2.3 (CPU compute nodes)
  - 10.0.2.4 (GPU compute node)
- **SLURM Configuration**: Uses 10.0.2.1 - 10.0.2.4 for node management

These network settings are configured and utilized in Warewulf for provisioning and PXE booting.

## Setup Flow

### Prerequisites
1. Install Rocky Linux 9.6 on head node
2. Jetson Orin Nano is flashed (can be done with Ubuntu host: [Jetson AI Lab Setup Guide](https://www.jetson-ai-lab.com/initial_setup_jon_sdkm.html))

### Cluster Setup Steps
1. Set up network configuration
2. Install and configure Warewulf
3. Install and configure SLURM
4. Use Spack for package management
5. Configure Lmod to load packages for users
6. Set up logging management (ELK stack)
7. Configure system monitoring (MonSTER + Grafana)

## Project Structure

```
.
├── src/              # Source code (implementation)
│   ├── ansible/      # Ansible implementation
│   ├── shell/        # Shell implementation
│   └── common/       # Common utilities
│
├── docs/             # Project documentation
│   ├── architecture/ # System architecture
│   ├── development/  # Development guides
│   ├── deployment/   # Deployment guides
│   └── api/          # API documentation
│
├── examples/         # Reference examples
│   ├── ansible/      # Ansible examples
│   ├── shell/        # Shell examples
│   └── config/       # Configuration examples
│
├── tests/            # Test framework
│   ├── unit/         # Unit tests
│   ├── integration/  # Integration tests
│   ├── performance/  # Performance tests
│   └── data/         # Test data
│
├── tools/            # Development tools (project management)
│   ├── lint/         # Linting tools
│   ├── format/       # Code formatters
│   └── test/         # Test runners
│
├── config/           # Deployment configurations
│   ├── dev/          # Development config
│   ├── test/         # Test config
│   └── prod/         # Production config
│
├── .gitlab-ci.yml    # CI/CD configuration
├── CONTRIBUTING.md   # Contribution guidelines
└── LICENSE           # Project license
```

## Directory Organization

### Source Code (`src/`)
- Contains the actual implementation code
- Split into Ansible and shell methods
- Includes common utilities
- Focused on HPC cluster functionality

### Project Resources
- **Documentation** (`docs/`): Project documentation and guides
- **Examples** (`examples/`): Reference implementations
- **Tests** (`tests/`): Test framework and data

### Project Management
- **Tools** (`tools/`): Development utilities
  - Used for maintaining the project
  - Not part of the HPC setup
  - Includes linting, formatting, and testing tools

- **Configuration** (`config/`): Deployment settings
  - Environment-specific configurations
  - Controls how the code runs
  - Not part of the source code

## Configuration Methods

### Ansible Method
- Uses Ansible for configuration management
- Located in `src/ansible/`
- Features:
  - Declarative configuration
  - Idempotent operations
  - Role-based organization
  - Inventory management
- Documentation: `docs/deployment/ansible/`
- Examples: `examples/ansible/`

### Shell Method
- Uses shell scripts for configuration
- Located in `src/shell/`
- Features:
  - Imperative configuration
  - Direct system control
  - Script-based automation
  - Template-based configuration
- Documentation: `docs/deployment/shell/`
- Examples: `examples/shell/`

## Documentation

- Architecture: `docs/architecture/`
- Development: `docs/development/`
- Deployment: `docs/deployment/`
- API: `docs/api/`

## Examples

- Ansible: `examples/ansible/`
- Shell: `examples/shell/`
- Configuration: `examples/config/`

## Testing

- Unit Tests: `tests/unit/`
- Integration Tests: `tests/integration/`
- Performance Tests: `tests/performance/`
- Test Data: `tests/data/`

## Development

### Prerequisites
- Ansible 2.9+
- Bash 4.4+
- Python 3.8+
- Git

### Setup
```bash
# Clone repository
git clone https://github.com/ttu-hpc/Mini-HPC-Setup.git
cd Mini-HPC-Setup

# Install development tools
./tools/setup-dev-env.sh

# Run tests
./tests/run-tests.sh
```

### Configuration
- Development: `config/dev/`
- Testing: `config/test/`
- Production: `config/prod/`

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for contribution guidelines.

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

## Support

For issues and questions:
- Email: hpc-dev@ttu.edu
- Documentation: `docs/`
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues)