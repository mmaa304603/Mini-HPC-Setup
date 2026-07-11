#!/bin/bash

# Shared test configuration for Mini-HPC shell tests.
# Tests may override these values through environment variables.

TEST_REPO_ROOT="${TEST_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
TEST_SRC_SHELL_DIR="${TEST_SRC_SHELL_DIR:-$TEST_REPO_ROOT/src/shell}"
TEST_RESULTS_DIR="${TEST_RESULTS_DIR:-$TEST_REPO_ROOT/test-results}"

# Space-separated component list used by shell integration tests.
HPC_TEST_COMPONENTS="${HPC_TEST_COMPONENTS:-spack apptainer}"

# Space-separated hostnames or IPs. When empty, compute-node checks are skipped
# unless HPC_TEST_ENABLE_COMPUTE=1 allows tests to fall back to slurm.conf nodes.
HPC_TEST_COMPUTE_NODES="${HPC_TEST_COMPUTE_NODES:-}"
HPC_TEST_ENABLE_COMPUTE="${HPC_TEST_ENABLE_COMPUTE:-0}"
HPC_TEST_SSH_USER="${HPC_TEST_SSH_USER:-root}"
HPC_TEST_SSH_OPTS="${HPC_TEST_SSH_OPTS:--o BatchMode=yes -o ConnectTimeout=5}"
