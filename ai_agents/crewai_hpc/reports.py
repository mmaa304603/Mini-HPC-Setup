from __future__ import annotations

import platform
from datetime import datetime
from pathlib import Path

from .audit import collect_findings, read_sources
from .constants import REPO_ROOT, SOURCE_FILES
from .environment import apply_sqlite_workaround, configure_crewai_storage


def dry_run_report(output_path: Path) -> None:
    sources = read_sources()
    strengths, risks = collect_findings(sources)
    now = datetime.now().astimezone().isoformat(timespec="seconds")

    report = [
        "# CrewAI HPC Agent Evidence",
        "",
        "- Timestamp: `{0}`".format(now),
        "- Repository: `{0}`".format(REPO_ROOT),
        "- Mode used: `--dry-run` because live CrewAI dependencies/API key were not available on this host.",
        "- Intended live command: `python ai_agents/crewai_hpc/hpc_crewai.py --use-crewai`",
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
            "1. Show this script as the CrewAI implementation: `ai_agents/crewai_hpc/hpc_crewai.py`.",
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
            "PYTHONPATH=/tmp/codex-crewai-050 python3 ai_agents/crewai_hpc/"
            "hpc_crewai.py --instantiate-proof"
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
            "- Dry-run audit report: `ai_agents/crewai_hpc/crewai_hpc_evidence.md`",
            "- CrewAI implementation: `ai_agents/crewai_hpc/hpc_crewai.py`",
        ]
    )
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text("\n".join(lines), encoding="utf-8")
