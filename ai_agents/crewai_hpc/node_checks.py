from __future__ import annotations

import json
import os
import subprocess
from typing import Dict

from .constants import CPU_NODES, NODE_APPTAINER_CHECKS, NODE_SPACK_CHECKS, REPO_ROOT


def run_wwctl_node_check(
    node: str,
    check_name: str,
    checks: Dict[str, str],
    label: str,
    timeout: int = 30,
) -> str:
    if node not in CPU_NODES:
        return "Refused: node must be one of {0}.".format(", ".join(CPU_NODES))
    if check_name not in checks:
        return "Refused: check_name must be one of {0}.".format(
            ", ".join(sorted(checks))
        )

    remote_command = "bash -lc {0}".format(json.dumps(checks[check_name]))
    password = os.environ.get("HPC_SUDO_PASSWORD")
    if password:
        command = ["sudo", "-S", "wwctl", "ssh", node, remote_command]
        stdin = password + "\n"
    else:
        command = ["sudo", "-n", "wwctl", "ssh", node, remote_command]
        stdin = None

    try:
        result = subprocess.run(
            command,
            cwd=str(REPO_ROOT),
            input=stdin,
            text=True,
            capture_output=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return "node={0} check={1} label={2} timed out after {3}s".format(
            node, check_name, label, timeout
        )
    except Exception as exc:
        return "node={0} check={1} label={2} error: {3}".format(
            node, check_name, label, exc
        )

    output = (result.stdout + result.stderr).strip()
    return "node={0} check={1} label={2} exit_code={3}\n{4}".format(
        node, check_name, label, result.returncode, output
    )

def run_wwctl_spack_check(node: str, check_name: str, timeout: int = 30) -> str:
    return run_wwctl_node_check(node, check_name, NODE_SPACK_CHECKS, "spack", timeout)

def run_wwctl_apptainer_check(node: str, check_name: str, timeout: int = 30) -> str:
    return run_wwctl_node_check(
        node, check_name, NODE_APPTAINER_CHECKS, "apptainer", timeout
    )

def check_node_spack(check_name: str = "version", timeout: int = 30) -> int:
    for node in CPU_NODES:
        print("== {0} ==".format(node))
        print(run_wwctl_spack_check(node, check_name, timeout=timeout))
        print()
    return 0

def check_node_apptainer(check_name: str = "version", timeout: int = 30) -> int:
    for node in CPU_NODES:
        print("== {0} ==".format(node))
        print(run_wwctl_apptainer_check(node, check_name, timeout=timeout))
        print()
    return 0
