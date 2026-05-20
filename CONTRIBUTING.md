# Contributing to Mini HPC Setup

Thank you for your interest in contributing to the Mini HPC Setup project! This document provides guidelines and instructions for contributing.

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md).

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/your-username/Mini-HPC-Setup.git`
3. Create a new branch: `git checkout -b feature/your-feature-name`

## Development Workflow

1. Make your changes
2. Run tests: `./tests/run_all_tests.sh`
3. Update documentation if needed
4. Commit changes: `git commit -m "Description of changes"`
5. Push to your fork: `git push origin feature/your-feature-name`
6. Create a Pull Request

## Git Configuration

### Line Endings

To ensure consistent line endings across different operating systems, configure Git according to your OS:

#### For Linux/Mac Users:
```bash
git config --global core.autocrlf input
```

#### For Windows Users:
```bash
git config --global core.autocrlf true
```

This configuration, along with the project's `.gitattributes` file, will ensure that:
- Line endings are normalized to LF (Linux-style) in the repository
- Files are checked out using the appropriate line endings for your OS
- Shell scripts and other specific files always maintain LF endings

### Before Committing

1. Ensure your IDE is configured to respect `.editorconfig` and `.gitattributes`
2. Check for mixed line endings before committing:
   ```bash
   git diff --check
   ```
3. If you find mixed line endings, you can normalize them:
   ```bash
   # Normalize line endings in your local repository
   git add --renormalize .
   ```

### Working with Existing Files

If you encounter line ending issues with existing files:

1. Remove the files from Git's index (don't worry, your files won't be deleted):
   ```bash
   git rm --cached -r .
   ```

2. Add all the files back:
   ```bash
   git add .
   ```

3. Commit the changes:
   ```bash
   git commit -m "Normalize line endings"
   ```

## Code Style

- Follow shell script best practices
- Use consistent indentation (4 spaces)
- Add comments for complex logic
- Include error handling
- Follow existing code patterns

## Testing

- Write unit tests for new features
- Update existing tests if needed
- Run all tests before submitting PR
- Ensure tests pass in CI/CD pipeline

## Documentation

- Update relevant documentation
- Add comments to code
- Include examples if applicable
- Update README if needed

## Pull Request Process

1. Ensure PR description clearly describes changes
2. Link related issues
3. Request review from maintainers
4. Address review comments
5. Wait for approval before merging

## Issue Reporting

- Use the issue template
- Provide detailed information
- Include error messages
- Add steps to reproduce
- Specify environment details

## Security

- Report security issues privately
- Follow security best practices
- Don't include sensitive information
- Use secure coding practices

## License

By contributing, you agree that your contributions will be licensed under the project's [LICENSE](LICENSE).

## Contact

For questions or help:
- Email: hpc-support@ttu.edu
- Documentation: [docs/](docs/)
- Issues: [GitHub Issues](https://github.com/ttu-hpc/Mini-HPC-Setup/issues) 