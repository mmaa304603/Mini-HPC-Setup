from __future__ import annotations

import re
import subprocess
import os
from pathlib import Path

from .constants import CPU_NODES, REPO_ROOT


SHARED_DIR = Path("/shared")


def run_command(command: list[str], timeout: int = 120) -> tuple[int, str]:
    try:
        result = subprocess.run(
            command,
            cwd=str(REPO_ROOT),
            text=True,
            capture_output=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return 124, "Command timed out after {0}s: {1}".format(
            timeout, " ".join(command)
        )
    return result.returncode, (result.stdout + result.stderr).strip()


def run_sudo_command(command: list[str], timeout: int = 60) -> tuple[int, str]:
    password = os.environ.get("HPC_SUDO_PASSWORD")
    if password:
        sudo_command = ["sudo", "-S"] + command
        stdin = password + "\n"
    else:
        sudo_command = ["sudo", "-n"] + command
        stdin = None
    try:
        result = subprocess.run(
            sudo_command,
            cwd=str(REPO_ROOT),
            input=stdin,
            text=True,
            capture_output=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired:
        return 124, "Command timed out after {0}s: {1}".format(
            timeout, " ".join(sudo_command)
        )
    return result.returncode, (result.stdout + result.stderr).strip()


def set_slurm_node_state(
    node: str,
    state: str,
    reason: str = "operator-approved maintenance demo",
) -> str:
    node = node.strip()
    state = state.strip().upper()
    reason = reason.strip() or "operator-approved maintenance demo"

    if node not in CPU_NODES:
        return "Refused: node must be one of {0}.".format(", ".join(CPU_NODES))
    if state not in {"DRAIN", "DOWN", "RESUME"}:
        return "Refused: state must be one of DRAIN, DOWN, RESUME."
    if len(reason) > 120 or "\n" in reason or "\r" in reason:
        return "Refused: reason must be a single line under 120 characters."
    if state in {"DRAIN", "DOWN"} and not reason:
        return "Refused: DRAIN/DOWN requires a reason."

    command = ["scontrol", "update", "NodeName={0}".format(node), "State={0}".format(state)]
    if state in {"DRAIN", "DOWN"}:
        command.append("Reason={0}".format(reason))

    code, output = run_sudo_command(command, timeout=60)
    show_code, show_output = run_command(["scontrol", "show", "node", node], timeout=30)
    return (
        "scontrol update exit_code={0}\n{1}\n\n"
        "scontrol show node {2} exit_code={3}\n{4}"
    ).format(code, output, node, show_code, show_output)


def show_slurm_node(node: str | None = None) -> str:
    if node:
        node = node.strip()
        if node not in CPU_NODES:
            return "Refused: node must be one of {0}.".format(", ".join(CPU_NODES))
        command = ["scontrol", "show", "node", node]
    else:
        command = ["sinfo", "-N"]
    code, output = run_command(command, timeout=30)
    return "exit_code={0}\n{1}".format(code, output)


def submit_slurm_sbatch_demo(
    sleep_seconds: int = 45,
    nodes: int = 1,
    ntasks: int = 1,
    time_limit: str = "00:02:00",
) -> str:
    if sleep_seconds < 1 or sleep_seconds > 300:
        return "Refused: sleep_seconds must be between 1 and 300."
    if nodes < 1 or nodes > 3:
        return "Refused: nodes must be between 1 and 3."
    if ntasks < 1 or ntasks > 12:
        return "Refused: ntasks must be between 1 and 12."
    if not re.fullmatch(r"\d{2}:\d{2}:\d{2}", time_limit):
        return "Refused: time_limit must use HH:MM:SS format."

    wrapped = (
        'echo "job started"; '
        "hostname; "
        "date -Ins; "
        "echo SLURM_JOB_ID=$SLURM_JOB_ID; "
        "echo SLURM_NODELIST=$SLURM_NODELIST; "
        "sleep {0}; "
        'echo "job finished"; '
        "date -Ins"
    ).format(sleep_seconds)

    command = [
        "sbatch",
        "--job-name=crewai-slurm-demo",
        "--nodes={0}".format(nodes),
        "--ntasks={0}".format(ntasks),
        "--time={0}".format(time_limit),
        "--output=/tmp/crewai-slurm-demo-%j.out",
        "--wrap={0}".format(wrapped),
    ]
    code, output = run_command(command, timeout=30)
    match = re.search(r"Submitted batch job\s+(\d+)", output)
    job_id = match.group(1) if match else "unknown"
    return (
        "sbatch exit_code={0}\n{1}\n\n"
        "Job ID: {2}\n"
        "Expected output file: /tmp/crewai-slurm-demo-{2}.out\n"
        "Monitor with: squeue -j {2}\n"
        "Inspect later with: cat /tmp/crewai-slurm-demo-{2}.out"
    ).format(code, output, job_id)


def validate_shared_script_name(script_name: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9_.-]+\.sbatch", script_name):
        raise ValueError("script_name must be a simple .sbatch filename without slashes.")
    return script_name


def validate_shared_python_name(script_name: str) -> str:
    if not re.fullmatch(r"[A-Za-z0-9_.-]+\.py", script_name):
        raise ValueError("python_script must be a simple .py filename without slashes.")
    return script_name


def create_shared_python_sbatch_script(
    script_name: str = "script.sbatch",
    python_script: str = "script.py",
    sleep_seconds: int = 10,
    nodes: int = 1,
    ntasks: int = 1,
    time_limit: str = "00:02:00",
) -> str:
    try:
        script_name = validate_shared_script_name(script_name)
        python_script = validate_shared_python_name(python_script)
    except ValueError as exc:
        return "Refused: {0}".format(exc)
    if sleep_seconds < 0 or sleep_seconds > 300:
        return "Refused: sleep_seconds must be between 0 and 300."
    if nodes < 1 or nodes > 3:
        return "Refused: nodes must be between 1 and 3."
    if ntasks < 1 or ntasks > 12:
        return "Refused: ntasks must be between 1 and 12."
    if not re.fullmatch(r"\d{2}:\d{2}:\d{2}", time_limit):
        return "Refused: time_limit must use HH:MM:SS format."
    if not SHARED_DIR.exists():
        return "Refused: /shared does not exist on this host."

    script_path = SHARED_DIR / script_name
    python_path = SHARED_DIR / python_script
    output_pattern = "/shared/python-sbatch-%j.out"
    content = """#!/bin/bash
#SBATCH --job-name=crewai-python-demo
#SBATCH --nodes={nodes}
#SBATCH --ntasks={ntasks}
#SBATCH --time={time_limit}
#SBATCH --output={output_pattern}

set -euo pipefail

echo "job started"
hostname
date -Ins
echo "SLURM_JOB_ID=${{SLURM_JOB_ID:-unknown}}"
echo "SLURM_NODELIST=${{SLURM_NODELIST:-unknown}}"

srun python3 {python_path}

sleep {sleep_seconds}

echo "job finished"
date -Ins
""".format(
        nodes=nodes,
        ntasks=ntasks,
        time_limit=time_limit,
        output_pattern=output_pattern,
        python_path=python_path,
        sleep_seconds=sleep_seconds,
    )
    script_path.write_text(content, encoding="utf-8")
    script_path.chmod(0o755)
    return (
        "Created Slurm Python wrapper: {0}\n"
        "Python payload: {1}\n"
        "Submit with: sbatch {0}\n"
        "Output pattern: {2}"
    ).format(script_path, python_path, output_pattern)


def create_shared_sbatch_demo_script(
    script_name: str = "test_script_aug19.sbatch",
    sleep_seconds: int = 45,
    nodes: int = 1,
    ntasks: int = 1,
    time_limit: str = "00:02:00",
) -> str:
    try:
        script_name = validate_shared_script_name(script_name)
    except ValueError as exc:
        return "Refused: {0}".format(exc)
    if sleep_seconds < 1 or sleep_seconds > 300:
        return "Refused: sleep_seconds must be between 1 and 300."
    if nodes < 1 or nodes > 3:
        return "Refused: nodes must be between 1 and 3."
    if ntasks < 1 or ntasks > 12:
        return "Refused: ntasks must be between 1 and 12."
    if not re.fullmatch(r"\d{2}:\d{2}:\d{2}", time_limit):
        return "Refused: time_limit must use HH:MM:SS format."
    if not SHARED_DIR.exists():
        return "Refused: /shared does not exist on this host."

    script_path = SHARED_DIR / script_name
    output_pattern = "/shared/crewai-slurm-demo-%j.out"
    content = """#!/bin/bash
#SBATCH --job-name=crewai-shared-demo
#SBATCH --nodes={nodes}
#SBATCH --ntasks={ntasks}
#SBATCH --time={time_limit}
#SBATCH --output={output_pattern}

set -euo pipefail

echo "job started"
hostname
date -Ins
echo "SLURM_JOB_ID=${{SLURM_JOB_ID:-unknown}}"
echo "SLURM_NODELIST=${{SLURM_NODELIST:-unknown}}"

sum=0
for value in $(seq 1 100); do
  sum=$((sum + value))
done
echo "sum_1_to_100=${{sum}}"

sleep {sleep_seconds}

echo "job finished"
date -Ins
""".format(
        nodes=nodes,
        ntasks=ntasks,
        time_limit=time_limit,
        output_pattern=output_pattern,
        sleep_seconds=sleep_seconds,
    )
    script_path.write_text(content, encoding="utf-8")
    script_path.chmod(0o755)
    return (
        "Created fixed Slurm demo script: {0}\n"
        "Submit with: sbatch {0}\n"
        "Output pattern: {1}"
    ).format(script_path, output_pattern)


def submit_shared_sbatch_demo_script(script_name: str = "test_script_aug19.sbatch") -> str:
    try:
        script_name = validate_shared_script_name(script_name)
    except ValueError as exc:
        return "Refused: {0}".format(exc)
    script_path = SHARED_DIR / script_name
    if not script_path.exists():
        return "Refused: script does not exist: {0}".format(script_path)

    code, output = run_command(["sbatch", str(script_path)], timeout=30)
    match = re.search(r"Submitted batch job\s+(\d+)", output)
    job_id = match.group(1) if match else "unknown"
    return (
        "sbatch {0} exit_code={1}\n{2}\n\n"
        "Job ID: {3}\n"
        "Expected output pattern: /shared/crewai-slurm-demo-{3}.out\n"
        "Monitor with: squeue -j {3}\n"
        "Inspect later with: cat /shared/crewai-slurm-demo-{3}.out"
    ).format(script_path, code, output, job_id)


def run_slurm_srun_demo(
    nodes: int = 1,
    ntasks: int = 1,
    sleep_seconds: int = 10,
    timeout: int = 120,
) -> str:
    if sleep_seconds < 0 or sleep_seconds > 120:
        return "Refused: sleep_seconds must be between 0 and 120."
    if nodes < 1 or nodes > 3:
        return "Refused: nodes must be between 1 and 3."
    if ntasks < 1 or ntasks > 12:
        return "Refused: ntasks must be between 1 and 12."

    command = [
        "srun",
        "-N{0}".format(nodes),
        "-n{0}".format(ntasks),
        "--ntasks-per-node=1",
        "bash",
        "-lc",
        'echo "NODE=$(hostname) TIME=$(date -Ins)"; sleep {0}'.format(sleep_seconds),
    ]
    code, output = run_command(command, timeout=timeout)
    return "srun exit_code={0}\n{1}".format(code, output)


def slurm_job_status(job_id: str | None = None) -> str:
    if job_id and not re.fullmatch(r"\d+", job_id):
        return "Refused: job_id must be numeric."
    if job_id:
        commands = [
            ["squeue", "-j", job_id],
            [
                "bash",
                "-lc",
                "sacct -j {0} --format=JobID,JobName,State,Elapsed,NodeList%20 2>/dev/null".format(
                    job_id
                ),
            ],
        ]
    else:
        commands = [
            ["bash", "-lc", 'squeue -u "$USER"'],
            [
                "bash",
                "-lc",
                'sacct -u "$USER" --format=JobID,JobName,State,Elapsed,NodeList%20 -S today 2>/dev/null | tail -30',
            ],
        ]

    chunks = []
    for command in commands:
        code, output = run_command(command, timeout=30)
        chunks.append("$ {0}\nexit_code={1}\n{2}".format(" ".join(command), code, output))
    return "\n\n".join(chunks)


def slurm_demo_output(job_id: str) -> str:
    if not re.fullmatch(r"\d+", job_id):
        return "Refused: job_id must be numeric."
    path = Path("/tmp") / "crewai-slurm-demo-{0}.out".format(job_id)
    if not path.exists():
        return "Output file not found yet: {0}".format(path)
    return path.read_text(encoding="utf-8", errors="replace")


def shared_slurm_demo_output(job_id: str) -> str:
    if not re.fullmatch(r"\d+", job_id):
        return "Refused: job_id must be numeric."
    path = SHARED_DIR / "crewai-slurm-demo-{0}.out".format(job_id)
    if not path.exists():
        return "Output file not found yet: {0}".format(path)
    return path.read_text(encoding="utf-8", errors="replace")
