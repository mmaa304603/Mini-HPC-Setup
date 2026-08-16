#!/usr/bin/env python3
# CrewAI demo for Mini HPC setup/configuration/management.

from __future__ import annotations

import argparse
import json
import os
import platform
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Any, Dict, Iterable, List, Tuple


REPO_ROOT = Path(__file__).resolve().parents[2]

SOURCE_FILES = {
    "README": "README.md",
    "network_shell_config": "src/shell/components/network/network.conf",
    "warewulf_node_config": "src/shell/components/warewulf/nodes.conf",
    "slurm_shell_config": "src/shell/components/slurm/slurm.conf",
    "slurm_ansible_template": "src/ansible/components/slurm/templates/slurm.conf.j2",
    "monitoring_doc": "docs/monitoring.md",
    "security_doc": "docs/security.md",
}

CONFIG_TARGETS = {
    "network": "src/shell/components/network/network.conf",
    "warewulf": "src/shell/components/warewulf/nodes.conf",
    "slurm": "src/shell/components/slurm/slurm.conf",
    "spack": "src/shell/components/spack/spack.conf",
    "apptainer": "src/shell/components/apptainer/apptainer.conf",
}

SAFE_INSPECTION_COMMANDS = {
    "sinfo": ["sinfo"],
    "wwctl_node_list": ["wwctl", "node", "list"],
    "wwctl_overlay_list": ["wwctl", "overlay", "list"],
    "wwctl_profile_list": ["wwctl", "profile", "list"],
    "spack_version": ["bash", "-lc", "source /etc/profile.d/spack.sh 2>/dev/null || true; spack --version"],
    "spack_find": ["bash", "-lc", "source /etc/profile.d/spack.sh 2>/dev/null || true; spack find"],
    "spack_compiler_list": [
        "bash",
        "-lc",
        "source /etc/profile.d/spack.sh 2>/dev/null || true; spack compiler list",
    ],
    "spack_config_get": [
        "bash",
        "-lc",
        "source /etc/profile.d/spack.sh 2>/dev/null || true; spack config get",
    ],
    "spack_env_list": ["bash", "-lc", "source /etc/profile.d/spack.sh 2>/dev/null || true; spack env list"],
    "apptainer_version": ["bash", "-lc", "apptainer --version || singularity --version"],
    "apptainer_config_global": [
        "bash",
        "-lc",
        "test -r /etc/apptainer/apptainer.conf && sed -n '1,120p' /etc/apptainer/apptainer.conf || true",
    ],
}

CPU_NODES = ["cpu01", "cpu02", "cpu03"]

NODE_SPACK_CHECKS = {
    "profile": (
        "test -r /etc/profile.d/spack.sh && echo spack-profile-present || "
        "echo spack-profile-missing; ls -l /etc/profile.d/spack.sh /opt/spack/bin/spack 2>/dev/null || true"
    ),
    "version": (
        "source /etc/profile.d/spack.sh 2>/dev/null || true; "
        "command -v spack || true; spack --version"
    ),
    "find": "source /etc/profile.d/spack.sh 2>/dev/null || true; spack find",
    "compiler_list": (
        "source /etc/profile.d/spack.sh 2>/dev/null || true; spack compiler list"
    ),
}

NODE_APPTAINER_CHECKS = {
    "profile": (
        "command -v apptainer || command -v singularity || true; "
        "test -r /etc/apptainer/apptainer.conf && echo apptainer-config-present || "
        "echo apptainer-config-missing; "
        "ls -l /usr/bin/apptainer /usr/local/bin/apptainer /etc/apptainer/apptainer.conf 2>/dev/null || true"
    ),
    "version": "apptainer --version || singularity --version",
    "config": "test -r /etc/apptainer/apptainer.conf && sed -n '1,120p' /etc/apptainer/apptainer.conf || true",
    "exec_test": (
        "apptainer exec docker://alpine:latest echo apptainer-exec-ok "
        "|| singularity exec docker://alpine:latest echo singularity-exec-ok"
    ),
}


def apply_sqlite_workaround() -> str:
    """Use pysqlite3 when system sqlite is too old for ChromaDB/CrewAI."""
    try:
        import sqlite3

        version = tuple(int(part) for part in sqlite3.sqlite_version.split(".")[:3])
        if version >= (3, 35, 0):
            return "system sqlite3 {0}".format(sqlite3.sqlite_version)
    except Exception:
        pass

    try:
        import pysqlite3

        sys.modules["sqlite3"] = pysqlite3
        return "pysqlite3 workaround enabled"
    except ImportError:
        return "pysqlite3 not installed; ChromaDB may fail if sqlite3 < 3.35.0"


def configure_crewai_storage() -> str:
    storage_dir = REPO_ROOT / ".crewai_storage"
    storage_dir.mkdir(parents=True, exist_ok=True)
    os.environ.setdefault("CREWAI_STORAGE_DIR", str(storage_dir))
    return os.environ["CREWAI_STORAGE_DIR"]


def proposal_dir() -> Path:
    path = REPO_ROOT / "ai_agents" / "crewai_hpc_demo" / "change_proposals"
    path.mkdir(parents=True, exist_ok=True)
    return path


def default_transcript_path(mode: str) -> Path:
    timestamp = datetime.now().astimezone().strftime("%Y%m%d-%H%M%S")
    path = REPO_ROOT / "ai_agents" / "crewai_hpc_demo" / "transcripts"
    path.mkdir(parents=True, exist_ok=True)
    return path / "{0}-{1}.txt".format(mode, timestamp)


def append_transcript(path: Path, speaker: str, text: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write("\n## {0} {1}\n\n".format(speaker, datetime.now().astimezone().isoformat(timespec="seconds")))
        handle.write(str(text).strip())
        handle.write("\n")


def resolve_config_target(config_name: str) -> Path:
    if config_name not in CONFIG_TARGETS:
        raise ValueError("Unknown config target: {0}".format(config_name))
    return REPO_ROOT / CONFIG_TARGETS[config_name]


def validate_shell_value(value: str) -> None:
    if "\n" in value or "\r" in value:
        raise ValueError("New value must be a single line.")
    forbidden = ["`", "$(", ";", "&&", "||", "|", ">", "<"]
    if any(token in value for token in forbidden):
        raise ValueError("New value contains shell metacharacters and was refused.")


def format_shell_assignment(variable: str, value: str) -> str:
    if re.fullmatch(r"(true|false|[0-9]+)", value):
        return "{0}={1}".format(variable, value)
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return '{0}="{1}"'.format(variable, escaped)


def replace_shell_variable(path: Path, variable: str, value: str) -> Tuple[str, str]:
    if not re.fullmatch(r"[A-Z][A-Z0-9_]*", variable):
        raise ValueError("Variable name must look like an uppercase shell config variable.")
    validate_shell_value(value)

    text = path.read_text(encoding="utf-8")
    pattern = re.compile(r"^({0}=)(.*)$".format(re.escape(variable)), re.MULTILINE)
    match = pattern.search(text)
    if not match:
        raise ValueError("Variable {0} was not found in {1}".format(variable, path))

    old_line = match.group(0)
    new_line = format_shell_assignment(variable, value)
    updated = text[: match.start()] + new_line + text[match.end() :]
    path.write_text(updated, encoding="utf-8")
    return old_line, new_line


def apply_proposal(proposal_path: Path) -> int:
    if not proposal_path.is_absolute():
        proposal_path = REPO_ROOT / proposal_path
    proposal = json.loads(proposal_path.read_text(encoding="utf-8"))
    if proposal.get("type") != "shell_variable_change":
        print("Refused: only shell_variable_change proposals can be auto-applied.")
        print("Proposal type:", proposal.get("type"))
        return 2

    config_name = proposal["config_name"]
    variable = proposal["variable"]
    new_value = proposal["new_value"]
    target_path = resolve_config_target(config_name)
    old_line, new_line = replace_shell_variable(target_path, variable, new_value)
    print("Applied proposal:", proposal_path)
    print("File:", target_path.relative_to(REPO_ROOT))
    print("Old:", old_line)
    print("New:", new_line)
    return 0


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


def read_sources() -> Dict[str, str]:
    sources = {}
    for label, relative_path in SOURCE_FILES.items():
        path = REPO_ROOT / relative_path
        if path.exists():
            sources[label] = path.read_text(encoding="utf-8", errors="replace")
        else:
            sources[label] = "MISSING: {0}".format(relative_path)
    return sources


def shell_var(text: str, name: str) -> str:
    match = re.search(r"^{0}=[\"']?([^\"'\n#]+)".format(re.escape(name)), text, re.MULTILINE)
    return match.group(1).strip() if match else "not found"


def shell_array(text: str, name: str) -> List[str]:
    match = re.search(r"^{0}=\(([^)]*)\)".format(re.escape(name)), text, re.MULTILINE)
    if not match:
        return []
    return re.findall(r"[\"']([^\"']+)[\"']", match.group(1))


def collect_findings(sources: Dict[str, str]) -> Tuple[List[str], List[str]]:
    network = sources["network_shell_config"]
    warewulf = sources["warewulf_node_config"]
    slurm_shell = sources["slurm_shell_config"]
    slurm_template = sources["slurm_ansible_template"]

    strengths = []
    risks = []

    head_ip = shell_var(network, "HEAD_NODE_IP")
    cidr = shell_var(network, "CLUSTER_NETWORK_CIDR")
    dhcp_start = shell_var(network, "DHCP_START")
    dhcp_end = shell_var(network, "DHCP_END")
    compute_nodes = shell_array(warewulf, "COMPUTE_NODES")
    compute_ips = shell_array(warewulf, "COMPUTE_NODE_IPS")
    slurm_cpu_nodes = shell_array(slurm_shell, "SLURM_CPU_NODES")
    gpu_ip = shell_var(network, "GPU_NODE_IP")
    gpu_enabled = shell_var(slurm_shell, "SLURM_GPU_ENABLED")

    strengths.append(
        "Network plan is explicit: head node {0}, cluster CIDR {1}, DHCP range {2}-{3}.".format(
            head_ip, cidr, dhcp_start, dhcp_end
        )
    )
    strengths.append(
        "Warewulf CPU node inventory maps {0} nodes to {1} static IPs.".format(
            len(compute_nodes), len(compute_ips)
        )
    )
    strengths.append(
        "Slurm shell config defines CPU nodes {0} and separate GPU metadata for gpu01.".format(
            ", ".join(slurm_cpu_nodes) or "not found"
        )
    )

    if compute_nodes != slurm_cpu_nodes:
        risks.append(
            "Warewulf compute nodes and Slurm CPU node arrays differ: Warewulf={0}; Slurm={1}.".format(
                compute_nodes, slurm_cpu_nodes
            )
        )
    if "ClusterName=hpc-cluster" in slurm_template and "SLURM_CLUSTER_NAME=\"mini-hpc\"" in slurm_shell:
        risks.append(
            "Cluster naming differs between shell Slurm config (mini-hpc) and Ansible template (hpc-cluster)."
        )
    if "TaskPlugin=task/affinity" in slurm_template and "TaskPlugin=task/cgroup" in slurm_template:
        risks.append(
            "Ansible Slurm template sets TaskPlugin twice; prefer one combined TaskPlugin line."
        )
    if gpu_ip != "not found" and gpu_enabled.lower() == "false":
        risks.append(
            "GPU node IP exists ({0}) but SLURM_GPU_ENABLED is false; clarify whether gpu01 is in scope.".format(
                gpu_ip
            )
        )
    if len(compute_nodes) != len(compute_ips):
        risks.append("Warewulf node and IP arrays have different lengths.")
    if not risks:
        risks.append("No immediate cross-file consistency risks found in the inspected files.")

    return strengths, risks


def build_context(sources: Dict[str, str]) -> str:
    blocks = []
    for label, content in sources.items():
        relative_path = SOURCE_FILES[label]
        clipped = content[:4000]
        blocks.append("### {0} ({1})\n{2}".format(label, relative_path, clipped))
    return "\n\n".join(blocks)


def dry_run_report(output_path: Path) -> None:
    sources = read_sources()
    strengths, risks = collect_findings(sources)
    now = datetime.now().astimezone().isoformat(timespec="seconds")

    report = [
        "# CrewAI HPC Agent Demo Evidence",
        "",
        "- Timestamp: `{0}`".format(now),
        "- Repository: `{0}`".format(REPO_ROOT),
        "- Mode used: `--dry-run` because live CrewAI dependencies/API key were not available on this host.",
        "- Intended live command: `python ai_agents/crewai_hpc_demo/hpc_crewai_demo.py --use-crewai`",
        "",
        "## Objective",
        "",
        "Use CrewAI-style agents to assist one HPC management objective: audit Mini HPC setup/configuration files and produce management recommendations for Slurm, Warewulf, network, security, and monitoring readiness.",
        "",
        "## Crew Design",
        "",
        "- Agent 1, Cluster Configuration Auditor: inspects network, Warewulf, and Slurm configuration consistency.",
        "- Agent 2, Operations Reliability Reviewer: identifies deployment and management risks.",
        "- Agent 3, Technical Documentation Reviewer: turns findings into a concise evidence report.",
        "",
        "## Repository Files Inspected",
        "",
    ]
    for label, relative_path in SOURCE_FILES.items():
        status = "present" if (REPO_ROOT / relative_path).exists() else "missing"
        report.append("- `{0}` ({1})".format(relative_path, status))

    report.extend(["", "## Findings A CrewAI Run Should Validate", "", "### Strengths", ""])
    report.extend("- {0}".format(item) for item in strengths)
    report.extend(["", "### Risks / Management Actions", ""])
    report.extend("- {0}".format(item) for item in risks)
    report.extend(
        [
            "",
            "## What To Show",
            "",
            "1. Show this script as the CrewAI implementation: `ai_agents/crewai_hpc_demo/hpc_crewai_demo.py`.",
            "2. Show this report as the generated evidence artifact.",
            "3. Explain the current blocker honestly: the host has Python `{0}`, but current CrewAI requires Python 3.10+; no LLM API key is exported.".format(
                platform.python_version()
            ),
            "4. If Python 3.10+ and an API key are available, run the live command and replace this report with the CrewAI-generated one.",
            "",
        ]
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(report), encoding="utf-8")


def instantiate_crewai_proof(output_path: Path, model: str) -> None:
    """Create CrewAI objects without calling an external LLM.

    This is useful evidence when an API key is unavailable. It still imports
    CrewAI and constructs the actual Agent/Task/Crew objects for this HPC goal.
    """
    sqlite_status = apply_sqlite_workaround()
    storage_dir = configure_crewai_storage()
    try:
        from crewai import Agent, Crew, Task
    except ImportError as exc:
        raise SystemExit(
            "CrewAI is not importable. For this host, one working temporary path was: "
            "PYTHONPATH=/tmp/codex-crewai-050 python3 ai_agents/crewai_hpc_demo/"
            "hpc_crewai_demo.py --instantiate-proof"
        ) from exc

    agents = [
        Agent(
            role="Mini HPC Cluster Configuration Auditor",
            goal="Audit Slurm, Warewulf, and network configuration consistency.",
            backstory="HPC systems engineer reviewing a small research cluster.",
            memory=False,
            llm=model,
        ),
        Agent(
            role="HPC Operations Reliability Reviewer",
            goal="Recommend safe setup and management actions for cluster readiness.",
            backstory="Cluster operations reviewer focused on reliability and repeatability.",
            memory=False,
            llm=model,
        ),
        Agent(
            role="Technical Documentation Reviewer",
            goal="Summarize evidence that CrewAI was used for the HPC objective.",
            backstory="Technical reviewer preparing concise engineering evidence.",
            memory=False,
            llm=model,
        ),
    ]
    tasks = [
        Task(
            description="Inspect Mini HPC network, Warewulf, and Slurm files for consistency.",
            expected_output="Configuration strengths and risks with file evidence.",
            agent=agents[0],
        ),
        Task(
            description="Prioritize setup/configuration/management recommendations.",
            expected_output="Operations checklist for the Mini HPC cluster.",
            agent=agents[1],
        ),
        Task(
            description="Prepare a technical evidence report.",
            expected_output="Markdown evidence summary.",
            agent=agents[2],
        ),
    ]
    crew = Crew(agents=agents, tasks=tasks)

    now = datetime.now().astimezone().isoformat(timespec="seconds")
    lines = [
        "# CrewAI Instantiation Proof",
        "",
        "- Timestamp: `{0}`".format(now),
        "- Python: `{0}`".format(platform.python_version()),
        "- SQLite status: `{0}`".format(sqlite_status),
        "- CrewAI storage directory: `{0}`".format(storage_dir),
        "- CrewAI import: succeeded",
        "- Model configured: `{0}`".format(model),
        "- CrewAI objects created: `{0}` agents, `{1}` tasks, `{2}` crew".format(
            len(agents), len(tasks), crew.__class__.__name__
        ),
        "- LLM calls made: `0`",
        "- Reason LLM was not called: no API key is exported in this shell.",
        "",
        "## Agents Created",
        "",
    ]
    lines.extend("- `{0}`".format(agent.role) for agent in agents)
    lines.extend(["", "## Tasks Created", ""])
    lines.extend("- `{0}`".format(task.description) for task in tasks)
    lines.extend(
        [
            "",
            "## Related Evidence",
            "",
            "- Dry-run audit report: `ai_agents/crewai_hpc_demo/crewai_hpc_evidence.md`",
            "- CrewAI implementation: `ai_agents/crewai_hpc_demo/hpc_crewai_demo.py`",
        ]
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(lines), encoding="utf-8")


def run_crewai(output_path: Path, model: str) -> None:
    sources = read_sources()
    context = build_context(sources)

    sqlite_status = apply_sqlite_workaround()
    storage_dir = configure_crewai_storage()
    print("SQLite status:", sqlite_status)
    print("CrewAI storage:", storage_dir)

    try:
        from crewai import Agent, Crew, Process, Task
    except ImportError as exc:
        raise SystemExit(
            "CrewAI is not installed in this Python environment. Install with: "
            "python -m pip install -r ai_agents/crewai_hpc_demo/requirements.txt"
        ) from exc

    auditor = Agent(
        role="Mini HPC Cluster Configuration Auditor",
        goal="Find consistency issues across Slurm, Warewulf, network, security, and monitoring configuration.",
        backstory=(
            "You are an HPC systems engineer reviewing a small ARM/GPU cluster "
            "before deployment. You focus on concrete configuration evidence."
        ),
        llm=model,
        verbose=True,
    )

    reliability_reviewer = Agent(
        role="HPC Operations Reliability Reviewer",
        goal="Turn configuration findings into practical setup, management, and operations actions.",
        backstory=(
            "You manage small research clusters and care about repeatable setup, "
            "node lifecycle management, logging, monitoring, and recoverability."
        ),
        llm=model,
        verbose=True,
    )

    reporter = Agent(
        role="Technical Documentation Reviewer",
        goal="Produce a short, evidence-based report proving CrewAI was used for one HPC objective.",
        backstory=(
            "You write concise engineering summaries for technical review. "
            "You cite inspected files and separate completed work from blockers."
        ),
        llm=model,
        verbose=True,
    )

    audit_task = Task(
        description=(
            "Inspect the following Mini HPC repository context and identify concrete "
            "configuration strengths and risks.\n\n{0}".format(context)
        ),
        expected_output=(
            "A bullet list of strengths and risks with file names and specific management actions."
        ),
        agent=auditor,
    )

    operations_task = Task(
        description=(
            "Using the audit output, recommend the next management actions for "
            "setup/configuration/operations readiness. Include Slurm, Warewulf, "
            "networking, monitoring, and security where relevant."
        ),
        expected_output="A prioritized operations checklist with reasons.",
        agent=reliability_reviewer,
        context=[audit_task],
    )

    report_task = Task(
        description=(
            "Create a technical evidence report. Include the objective, the "
            "CrewAI agents used, files inspected, key findings, and commands to reproduce."
        ),
        expected_output="A Markdown evidence report.",
        agent=reporter,
        context=[audit_task, operations_task],
        output_file=str(output_path),
    )

    crew = Crew(
        agents=[auditor, reliability_reviewer, reporter],
        tasks=[audit_task, operations_task, report_task],
        process=Process.sequential,
        verbose=True,
    )
    result = crew.kickoff()

    if not output_path.exists():
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(str(result), encoding="utf-8")


def run_chat(model: str, transcript: Path | None = None) -> None:
    sources = read_sources()
    context = build_context(sources)
    transcript_path = transcript or default_transcript_path("chat")

    sqlite_status = apply_sqlite_workaround()
    storage_dir = configure_crewai_storage()
    print("SQLite status:", sqlite_status)
    print("CrewAI storage:", storage_dir)

    try:
        from crewai import Agent, Crew, Process, Task
    except ImportError as exc:
        raise SystemExit(
            "CrewAI is not installed in this Python environment. Install with: "
            "python -m pip install -r ai_agents/crewai_hpc_demo/requirements.txt"
        ) from exc

    agent = Agent(
        role="Mini HPC ChatOps Agent",
        goal=(
            "Answer questions about Mini HPC setup, configuration, troubleshooting, "
            "and management using the repository context."
        ),
        backstory=(
            "You are an HPC systems assistant helping configure and manage a small "
            "research cluster with Slurm, Warewulf, Ansible, shell scripts, monitoring, "
            "security, and backup workflows. Be concrete and cite repository files when useful."
        ),
        llm=model,
        verbose=False,
        memory=False,
    )

    print("Mini HPC CrewAI chat started. Type 'exit' or 'quit' to stop.")
    print("Transcript:", transcript_path)
    while True:
        try:
            question = input("\nhpc-agent> ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nChat ended.")
            return

        if question.lower() in {"exit", "quit", "q"}:
            print("Chat ended.")
            return
        if not question:
            continue
        append_transcript(transcript_path, "User", question)

        task = Task(
            description=(
                "Repository context:\n\n{0}\n\nUser question:\n{1}\n\n"
                "Answer as a practical HPC setup/configuration/management assistant. "
                "If you mention a repo artifact, include its path."
            ).format(context, question),
            expected_output="A concise, practical answer for the user's HPC question.",
            agent=agent,
        )
        crew = Crew(agents=[agent], tasks=[task], process=Process.sequential, verbose=False)
        result = crew.kickoff()
        append_transcript(transcript_path, "Agent", result)
        print("\n{0}".format(result))


def run_ops_chat(
    model: str,
    transcript: Path | None = None,
    node_timeout: int = 30,
) -> None:
    transcript_path = transcript or default_transcript_path("ops-chat")
    sqlite_status = apply_sqlite_workaround()
    storage_dir = configure_crewai_storage()
    print("SQLite status:", sqlite_status)
    print("CrewAI storage:", storage_dir)

    try:
        from crewai import Agent, Crew, Process, Task
        from crewai.tools import BaseTool
        from pydantic import BaseModel, Field
    except ImportError as exc:
        raise SystemExit(
            "CrewAI is not installed in this Python environment. Install with: "
            "python -m pip install -r ai_agents/crewai_hpc_demo/requirements.txt"
        ) from exc

    class ReadConfigInput(BaseModel):
        config_name: str = Field(
            description="One of: network, warewulf, slurm, spack, apptainer."
        )

    class ReadConfigTool(BaseTool):
        name: str = "read_hpc_config"
        description: str = (
            "Read an approved Mini HPC config file. Use this before recommending "
            "network, Warewulf, Slurm, Spack, or Apptainer changes."
        )
        args_schema: type[BaseModel] = ReadConfigInput

        def _run(self, config_name: str) -> str:
            try:
                path = resolve_config_target(config_name)
                return "FILE: {0}\n\n{1}".format(
                    path.relative_to(REPO_ROOT),
                    path.read_text(encoding="utf-8", errors="replace"),
                )
            except Exception as exc:
                return "ERROR: {0}".format(exc)

    class InspectionCommandInput(BaseModel):
        command_name: str = Field(
            description=(
                "One of: sinfo, wwctl_node_list, wwctl_overlay_list, "
                "wwctl_profile_list, spack_version, spack_find, "
                "spack_compiler_list, spack_config_get, spack_env_list, "
                "apptainer_version, apptainer_config_global."
            )
        )

    class SafeInspectionCommandTool(BaseTool):
        name: str = "run_safe_hpc_inspection_command"
        description: str = (
            "Run an approved read-only HPC inspection command. This cannot modify "
            "network, Slurm, Warewulf, Spack, or Apptainer settings."
        )
        args_schema: type[BaseModel] = InspectionCommandInput

        def _run(self, command_name: str) -> str:
            if command_name not in SAFE_INSPECTION_COMMANDS:
                return "Refused: command_name is not allowlisted."
            try:
                result = subprocess.run(
                    SAFE_INSPECTION_COMMANDS[command_name],
                    cwd=str(REPO_ROOT),
                    text=True,
                    capture_output=True,
                    timeout=20,
                )
                output = result.stdout + result.stderr
                return "exit_code={0}\n{1}".format(result.returncode, output.strip())
            except Exception as exc:
                return "ERROR: {0}".format(exc)

    class StageShellVariableChangeInput(BaseModel):
        config_name: str = Field(
            description="One of: network, warewulf, slurm, spack, apptainer."
        )
        variable: str = Field(description="Uppercase shell config variable to change.")
        new_value: str = Field(description="New scalar value for the variable.")
        reason: str = Field(description="Operational reason for the proposed change.")

    class StageShellVariableChangeTool(BaseTool):
        name: str = "stage_shell_variable_change"
        description: str = (
            "Stage, but do not apply, a scalar shell variable change for an approved "
            "Mini HPC config file. Use only after reading the relevant config. "
            "This creates a proposal JSON file that the operator must apply manually."
        )
        args_schema: type[BaseModel] = StageShellVariableChangeInput

        def _run(self, config_name: str, variable: str, new_value: str, reason: str) -> str:
            try:
                path = resolve_config_target(config_name)
                validate_shell_value(new_value)
                text = path.read_text(encoding="utf-8", errors="replace")
                current = shell_var(text, variable)
                if current == "not found":
                    return "Refused: variable {0} was not found in {1}.".format(
                        variable, path.relative_to(REPO_ROOT)
                    )
                now = datetime.now().astimezone().strftime("%Y%m%d-%H%M%S")
                proposal = {
                    "type": "shell_variable_change",
                    "created_at": datetime.now().astimezone().isoformat(timespec="seconds"),
                    "config_name": config_name,
                    "path": CONFIG_TARGETS[config_name],
                    "variable": variable,
                    "old_value": current,
                    "new_value": new_value,
                    "reason": reason,
                    "apply_command": (
                        "python ai_agents/crewai_hpc_demo/hpc_crewai_demo.py "
                        "--apply-proposal ai_agents/crewai_hpc_demo/change_proposals/"
                        "proposal-{0}-{1}.json"
                    ).format(variable.lower(), now),
                }
                output_path = proposal_dir() / "proposal-{0}-{1}.json".format(
                    variable.lower(), now
                )
                output_path.write_text(json.dumps(proposal, indent=2), encoding="utf-8")
                return (
                    "Staged proposal: {0}\n"
                    "Current: {1}={2}\n"
                    "Proposed: {1}={3}\n"
                    "Apply manually with:\n{4}"
                ).format(
                    output_path.relative_to(REPO_ROOT),
                    variable,
                    current,
                    new_value,
                    proposal["apply_command"],
                )
            except Exception as exc:
                return "ERROR: {0}".format(exc)

    class StageCommandProposalInput(BaseModel):
        command: str = Field(description="A proposed live HPC management command.")
        reason: str = Field(description="Reason the command is needed.")

    class StageCommandProposalTool(BaseTool):
        name: str = "stage_live_command_proposal"
        description: str = (
            "Stage a proposed live management command without executing it. Use for "
            "commands such as wwctl node set, wwctl overlay build, nmcli changes, "
            "or service restarts. Never executes the command."
        )
        args_schema: type[BaseModel] = StageCommandProposalInput

        def _run(self, command: str, reason: str) -> str:
            allowed_prefixes = [
                "wwctl node set ",
                "wwctl overlay build",
                "wwctl configure ",
                "spack install ",
                "spack uninstall ",
                "spack compiler find",
                "spack module ",
                "apptainer pull ",
                "apptainer build ",
                "apptainer exec ",
                "nmcli connection modify ",
                "systemctl restart ",
                "systemctl reload ",
            ]
            if not any(command.startswith(prefix) for prefix in allowed_prefixes):
                return "Refused: command prefix is not approved for proposal staging."
            now = datetime.now().astimezone().strftime("%Y%m%d-%H%M%S")
            proposal = {
                "type": "live_command_proposal",
                "created_at": datetime.now().astimezone().isoformat(timespec="seconds"),
                "command": command,
                "reason": reason,
                "note": "This proposal is not auto-applied. Review and run manually if approved.",
            }
            output_path = proposal_dir() / "command-proposal-{0}.json".format(now)
            output_path.write_text(json.dumps(proposal, indent=2), encoding="utf-8")
            return "Staged command proposal: {0}\nCommand: {1}".format(
                output_path.relative_to(REPO_ROOT), command
            )

    class NodeSpackCheckInput(BaseModel):
        node: str = Field(description="One of: cpu01, cpu02, cpu03, all.")
        check_name: str = Field(
            description="One of: profile, version, find, compiler_list."
        )

    class NodeSpackCheckTool(BaseTool):
        name: str = "run_compute_node_spack_check"
        description: str = (
            "Run an approved read-only Spack accessibility check on compute nodes "
            "through sudo wwctl ssh. Use this when asked to verify whether cpu nodes "
            "can access Spack. Supported nodes are cpu01, cpu02, cpu03, or all. "
            "Supported checks are profile, version, find, and compiler_list."
        )
        args_schema: type[BaseModel] = NodeSpackCheckInput

        def _run(self, node: str, check_name: str) -> str:
            nodes = CPU_NODES if node == "all" else [node]
            return "\n\n".join(
                run_wwctl_spack_check(item, check_name, timeout=node_timeout)
                for item in nodes
            )

    class NodeApptainerCheckInput(BaseModel):
        node: str = Field(description="One of: cpu01, cpu02, cpu03, all.")
        check_name: str = Field(
            description="One of: profile, version, config, exec_test."
        )

    class NodeApptainerCheckTool(BaseTool):
        name: str = "run_compute_node_apptainer_check"
        description: str = (
            "Run an approved read-only Apptainer accessibility check on compute nodes "
            "through sudo wwctl ssh. Use this when asked to verify whether cpu nodes "
            "can access Apptainer. Supported nodes are cpu01, cpu02, cpu03, or all. "
            "Supported checks are profile, version, config, and exec_test. The exec_test "
            "may pull a small image if it is not cached."
        )
        args_schema: type[BaseModel] = NodeApptainerCheckInput

        def _run(self, node: str, check_name: str) -> str:
            nodes = CPU_NODES if node == "all" else [node]
            return "\n\n".join(
                run_wwctl_apptainer_check(item, check_name, timeout=node_timeout)
                for item in nodes
            )

    tools = [
        ReadConfigTool(),
        SafeInspectionCommandTool(),
        StageShellVariableChangeTool(),
        StageCommandProposalTool(),
        NodeSpackCheckTool(),
        NodeApptainerCheckTool(),
    ]

    agent = Agent(
        role="Mini HPC Operations Agent",
        goal=(
            "Inspect Mini HPC configuration and stage safe, reviewable management "
            "changes for network, Warewulf, Slurm, Spack, and Apptainer."
        ),
        backstory=(
            "You are an HPC operations assistant. You use tools to inspect current "
            "state, explain risks, and stage changes for human approval. You never "
            "claim a change was applied unless a tool says it was applied."
        ),
        llm=model,
        tools=tools,
        verbose=True,
        memory=False,
    )

    print("Mini HPC CrewAI ops chat started. Type 'exit' or 'quit' to stop.")
    print("Transcript:", transcript_path)
    print("Config changes are staged first. Apply staged scalar config changes with --apply-proposal.")
    while True:
        try:
            question = input("\nhpc-ops-agent> ").strip()
        except (EOFError, KeyboardInterrupt):
            print("\nOps chat ended.")
            return

        if question.lower() in {"exit", "quit", "q"}:
            print("Ops chat ended.")
            return
        if not question:
            continue
        append_transcript(transcript_path, "User", question)

        task = Task(
            description=(
                "User request:\n{0}\n\n"
                "Use tools when useful. Read the relevant config before proposing "
                "changes. For file changes, stage a proposal with "
                "stage_shell_variable_change instead of applying it. For live commands, "
                "stage a command proposal instead of running it. Explain the resulting "
                "proposal path and any validation commands the operator should run."
            ).format(question),
            expected_output=(
                "A concise operations response with tool-backed findings, staged proposal "
                "paths when applicable, and clear next commands."
            ),
            agent=agent,
        )
        crew = Crew(agents=[agent], tasks=[task], process=Process.sequential, verbose=True)
        result = crew.kickoff()
        append_transcript(transcript_path, "Agent", result)
        print("\n{0}".format(result))


def check_environment() -> int:
    print("Python:", platform.python_version())
    print("Executable:", sys.executable)
    print("OPENAI_API_KEY set:", bool(os.environ.get("OPENAI_API_KEY")))
    print("ANTHROPIC_API_KEY set:", bool(os.environ.get("ANTHROPIC_API_KEY")))
    print("SQLite status:", apply_sqlite_workaround())
    print("CrewAI storage:", configure_crewai_storage())
    try:
        import crewai  # type: ignore

        print("CrewAI installed:", getattr(crewai, "__version__", "version unknown"))
    except Exception as exc:  # pragma: no cover - evidence command
        print("CrewAI installed: no ({0})".format(exc.__class__.__name__))
    return 0


def parse_args(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="CrewAI Mini HPC demo")
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--use-crewai", action="store_true", help="run the live CrewAI crew")
    mode.add_argument("--chat", action="store_true", help="start an interactive HPC CrewAI chatbot")
    mode.add_argument(
        "--ops-chat",
        action="store_true",
        help="start an operations chatbot with guarded HPC tools",
    )
    mode.add_argument(
        "--apply-proposal",
        metavar="PATH",
        help="apply a staged scalar shell config proposal",
    )
    mode.add_argument(
        "--check-node-spack",
        nargs="?",
        const="version",
        metavar="CHECK",
        help="run read-only Spack accessibility check on cpu01-cpu03; checks: profile, version, find, compiler_list",
    )
    mode.add_argument(
        "--check-node-apptainer",
        nargs="?",
        const="version",
        metavar="CHECK",
        help="run read-only Apptainer check on cpu01-cpu03; checks: profile, version, config, exec_test",
    )
    mode.add_argument("--dry-run", action="store_true", help="generate local evidence without CrewAI")
    mode.add_argument(
        "--instantiate-proof",
        action="store_true",
        help="import CrewAI and create Agent/Task/Crew objects without LLM calls",
    )
    mode.add_argument("--check-env", action="store_true", help="print environment readiness")
    parser.add_argument(
        "--output",
        default="ai_agents/crewai_hpc_demo/crewai_hpc_evidence.md",
        help="path for the generated report",
    )
    parser.add_argument(
        "--model",
        default=os.environ.get("CREWAI_MODEL", "gpt-4o-mini"),
        help="LLM model name for CrewAI",
    )
    parser.add_argument(
        "--transcript",
        help="optional transcript path for --chat or --ops-chat",
    )
    parser.add_argument(
        "--node-timeout",
        type=int,
        default=30,
        help="timeout in seconds for compute-node checks",
    )
    return parser.parse_args(list(argv))


def main(argv: Iterable[str] = sys.argv[1:]) -> int:
    args = parse_args(argv)
    output_path = (REPO_ROOT / args.output).resolve()

    if args.check_env:
        return check_environment()
    if args.dry_run:
        dry_run_report(output_path)
        print("Wrote dry-run evidence report:", output_path)
        return 0
    if args.instantiate_proof:
        instantiate_crewai_proof(output_path, args.model)
        print("Wrote CrewAI instantiation proof:", output_path)
        return 0
    if args.chat:
        run_chat(args.model, Path(args.transcript) if args.transcript else None)
        return 0
    if args.ops_chat:
        run_ops_chat(
            args.model,
            Path(args.transcript) if args.transcript else None,
            node_timeout=args.node_timeout,
        )
        return 0
    if args.apply_proposal:
        return apply_proposal(Path(args.apply_proposal))
    if args.check_node_spack:
        return check_node_spack(args.check_node_spack, timeout=args.node_timeout)
    if args.check_node_apptainer:
        return check_node_apptainer(args.check_node_apptainer, timeout=args.node_timeout)
    if args.use_crewai:
        run_crewai(output_path, args.model)
        print("Wrote CrewAI evidence report:", output_path)
        return 0

    return 2


if __name__ == "__main__":
    raise SystemExit(main())
