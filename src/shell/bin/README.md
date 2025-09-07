# Executables (bin)

Entry points and helper scripts for shell-based operations.

## Contents

- `hpc-manage` / `hpc_manage.sh`: cluster management entrypoints
- `hpc-monitor`: monitoring entrypoint
- `hpc-backup`: backup entrypoint
- `hpc-security`: security/hardening entrypoint
- `hpc-test`: test and validation entrypoint
- `build.sh`: assemble distribution artifacts
- `deploy.sh`: deploy built artifacts
- `cleanup.sh`: clean build and temp outputs
- `setup-dev-env.sh`: local dev environment setup
- `core/`, `setup/`, `tools/`: helper subcommands/utilities

## Usage

```bash
# Show help
./hpc-manage --help

# Example: run validations
./hpc-test --all

# Build and deploy
./build.sh && ./deploy.sh

# Cleanup outputs
./cleanup.sh
```

## Notes

- Executables source libraries from `../lib/` and configs from `../config/`.
- Ensure scripts are executable: `chmod +x ./hpc-* ./*.sh`.