#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
    cat <<USAGE
Usage: ./tests/run-tests.sh [all|unit|integration|runtime|performance|shell]

Environment:
  HPC_TEST_COMPONENTS       Components to verify, default: "spack apptainer"
  HPC_TEST_COMPUTE_NODES    Space-separated compute nodes for runtime checks
  HPC_TEST_ENABLE_COMPUTE   Set to 1 to use slurm.conf nodes when nodes are not specified
  HPC_TEST_SRUN_OPTS        Extra options for runtime srun checks
USAGE
}

run_if_present() {
    local runner="$1"

    if [ ! -x "$runner" ]; then
        echo "SKIP: missing or non-executable runner: ${runner#$REPO_ROOT/}"
        return 0
    fi

    "$runner"
}

case "${1:-all}" in
    all)
        run_if_present "$REPO_ROOT/tests/unit/shell/run_tests.sh"
        run_if_present "$REPO_ROOT/tests/unit/ansible/run_tests.sh"
        run_if_present "$REPO_ROOT/tests/integration/shell/run_tests.sh"
        ;;
    unit)
        run_if_present "$REPO_ROOT/tests/unit/shell/run_tests.sh"
        run_if_present "$REPO_ROOT/tests/unit/ansible/run_tests.sh"
        ;;
    integration)
        run_if_present "$REPO_ROOT/tests/integration/shell/run_tests.sh"
        ;;
    runtime)
        run_if_present "$REPO_ROOT/tests/runtime/shell/run_tests.sh"
        ;;
    shell)
        run_if_present "$REPO_ROOT/tests/unit/shell/run_tests.sh"
        run_if_present "$REPO_ROOT/tests/integration/shell/run_tests.sh"
        ;;
    performance)
        run_if_present "$REPO_ROOT/tests/performance/benchmarks/run_benchmarks.sh"
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        usage
        exit 2
        ;;
esac
