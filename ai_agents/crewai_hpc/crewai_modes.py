from __future__ import annotations

import json
import subprocess
from datetime import datetime
from pathlib import Path

from .audit import build_context, read_sources, shell_var
from .constants import CONFIG_TARGETS, CPU_NODES, REPO_ROOT, SAFE_INSPECTION_COMMANDS
from .environment import apply_sqlite_workaround, configure_crewai_storage
from .node_checks import run_wwctl_apptainer_check, run_wwctl_spack_check
from .proposals import proposal_dir, resolve_config_target, validate_shell_value
from .slurm_jobs import (
    create_shared_sbatch_demo_script,
    create_shared_python_sbatch_script,
    run_slurm_srun_demo,
    set_slurm_node_state,
    shared_slurm_demo_output,
    show_slurm_node,
    slurm_demo_output,
    slurm_job_status,
    submit_shared_sbatch_demo_script,
    submit_slurm_sbatch_demo,
)
from .transcripts import append_transcript, default_transcript_path


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
            "python -m pip install -r ai_agents/crewai_hpc/requirements.txt"
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
            "python -m pip install -r ai_agents/crewai_hpc/requirements.txt"
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
            "python -m pip install -r ai_agents/crewai_hpc/requirements.txt"
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
                "apptainer_version, apptainer_config_global, squeue_me, sacct_today."
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
                        "python ai_agents/crewai_hpc/hpc_crewai.py "
                        "--apply-proposal ai_agents/crewai_hpc/change_proposals/"
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

    class SubmitSlurmSbatchDemoInput(BaseModel):
        nodes: int = Field(default=1, description="Number of nodes, 1 to 3.")
        ntasks: int = Field(default=1, description="Number of tasks, 1 to 12.")
        sleep_seconds: int = Field(
            default=45, description="How long the demo job sleeps, 1 to 300 seconds."
        )

    class SubmitSlurmSbatchDemoTool(BaseTool):
        name: str = "submit_slurm_sbatch_demo"
        description: str = (
            "Submit a fixed safe Slurm sbatch demo job. This is not arbitrary command "
            "execution; it submits a short hostname/date/sleep job with output in /tmp."
        )
        args_schema: type[BaseModel] = SubmitSlurmSbatchDemoInput

        def _run(self, nodes: int = 1, ntasks: int = 1, sleep_seconds: int = 45) -> str:
            return submit_slurm_sbatch_demo(
                sleep_seconds=sleep_seconds,
                nodes=nodes,
                ntasks=ntasks,
            )

    class RunSlurmSrunDemoInput(BaseModel):
        nodes: int = Field(default=1, description="Number of nodes, 1 to 3.")
        ntasks: int = Field(default=1, description="Number of tasks, 1 to 12.")
        sleep_seconds: int = Field(
            default=10, description="How long the demo command sleeps, 0 to 120 seconds."
        )

    class RunSlurmSrunDemoTool(BaseTool):
        name: str = "run_slurm_srun_demo"
        description: str = (
            "Run a fixed safe Slurm srun demo command that prints hostname/date and sleeps. "
            "Use this for interactive allocation testing, not arbitrary shell commands."
        )
        args_schema: type[BaseModel] = RunSlurmSrunDemoInput

        def _run(self, nodes: int = 1, ntasks: int = 1, sleep_seconds: int = 10) -> str:
            return run_slurm_srun_demo(
                nodes=nodes,
                ntasks=ntasks,
                sleep_seconds=sleep_seconds,
                timeout=node_timeout,
            )

    class SlurmJobStatusInput(BaseModel):
        job_id: str | None = Field(
            default=None,
            description="Optional numeric Slurm job ID. If omitted, checks current user's queue.",
        )

    class SlurmJobStatusTool(BaseTool):
        name: str = "check_slurm_job_status"
        description: str = "Check Slurm queue/accounting for a job ID or current user."
        args_schema: type[BaseModel] = SlurmJobStatusInput

        def _run(self, job_id: str | None = None) -> str:
            return slurm_job_status(job_id)

    class SlurmDemoOutputInput(BaseModel):
        job_id: str = Field(description="Numeric Slurm job ID from the demo sbatch output.")

    class SlurmDemoOutputTool(BaseTool):
        name: str = "read_slurm_demo_output"
        description: str = "Read /tmp/crewai-slurm-demo-JOBID.out for a submitted demo job."
        args_schema: type[BaseModel] = SlurmDemoOutputInput

        def _run(self, job_id: str) -> str:
            return slurm_demo_output(job_id)

    class CreateSharedSbatchDemoInput(BaseModel):
        script_name: str = Field(
            default="test_script_aug19.sbatch",
            description="Simple .sbatch filename under /shared, no slashes.",
        )
        nodes: int = Field(default=1, description="Number of nodes, 1 to 3.")
        ntasks: int = Field(default=1, description="Number of tasks, 1 to 12.")
        sleep_seconds: int = Field(
            default=45, description="How long the demo job sleeps, 1 to 300 seconds."
        )

    class CreateSharedSbatchDemoTool(BaseTool):
        name: str = "create_shared_sbatch_demo_script"
        description: str = (
            "Create a fixed safe Slurm sbatch demo script under /shared. This writes "
            "only a predetermined hostname/date/simple-sum/sleep script, not arbitrary content."
        )
        args_schema: type[BaseModel] = CreateSharedSbatchDemoInput

        def _run(
            self,
            script_name: str = "test_script_aug19.sbatch",
            nodes: int = 1,
            ntasks: int = 1,
            sleep_seconds: int = 45,
        ) -> str:
            return create_shared_sbatch_demo_script(
                script_name=script_name,
                nodes=nodes,
                ntasks=ntasks,
                sleep_seconds=sleep_seconds,
            )

    class SubmitSharedSbatchDemoInput(BaseModel):
        script_name: str = Field(
            default="test_script_aug19.sbatch",
            description="Simple .sbatch filename under /shared, no slashes.",
        )

    class SubmitSharedSbatchDemoTool(BaseTool):
        name: str = "submit_shared_sbatch_demo_script"
        description: str = "Submit an existing fixed safe Slurm demo script from /shared."
        args_schema: type[BaseModel] = SubmitSharedSbatchDemoInput

        def _run(self, script_name: str = "test_script_aug19.sbatch") -> str:
            return submit_shared_sbatch_demo_script(script_name=script_name)

    class CreateSharedPythonSbatchInput(BaseModel):
        script_name: str = Field(
            default="script.sbatch",
            description="Simple .sbatch filename under /shared, no slashes.",
        )
        python_script: str = Field(
            default="script.py",
            description="Simple .py filename under /shared, no slashes.",
        )
        nodes: int = Field(default=1, description="Number of nodes, 1 to 3.")
        ntasks: int = Field(default=1, description="Number of tasks, 1 to 12.")
        sleep_seconds: int = Field(
            default=10, description="Optional post-run sleep, 0 to 300 seconds."
        )

    class CreateSharedPythonSbatchTool(BaseTool):
        name: str = "create_shared_python_sbatch_script"
        description: str = (
            "Create or overwrite a /shared Slurm sbatch wrapper that runs a /shared "
            "Python script with srun python3. This is a guarded file operation: filenames "
            "must be simple /shared .sbatch and .py names, with no arbitrary shell content."
        )
        args_schema: type[BaseModel] = CreateSharedPythonSbatchInput

        def _run(
            self,
            script_name: str = "script.sbatch",
            python_script: str = "script.py",
            nodes: int = 1,
            ntasks: int = 1,
            sleep_seconds: int = 10,
        ) -> str:
            return create_shared_python_sbatch_script(
                script_name=script_name,
                python_script=python_script,
                nodes=nodes,
                ntasks=ntasks,
                sleep_seconds=sleep_seconds,
            )

    class SharedSlurmDemoOutputInput(BaseModel):
        job_id: str = Field(description="Numeric Slurm job ID from the shared demo job.")

    class SharedSlurmDemoOutputTool(BaseTool):
        name: str = "read_shared_slurm_demo_output"
        description: str = "Read /shared/crewai-slurm-demo-JOBID.out for a submitted shared demo job."
        args_schema: type[BaseModel] = SharedSlurmDemoOutputInput

        def _run(self, job_id: str) -> str:
            return shared_slurm_demo_output(job_id)

    class ShowSlurmNodeInput(BaseModel):
        node: str | None = Field(
            default=None,
            description="Optional node name: cpu01, cpu02, or cpu03. Omit for sinfo -N.",
        )

    class ShowSlurmNodeTool(BaseTool):
        name: str = "show_slurm_node_state"
        description: str = "Show Slurm node state using sinfo -N or scontrol show node."
        args_schema: type[BaseModel] = ShowSlurmNodeInput

        def _run(self, node: str | None = None) -> str:
            return show_slurm_node(node)

    class SetSlurmNodeStateInput(BaseModel):
        node: str = Field(description="One of: cpu01, cpu02, cpu03.")
        state: str = Field(description="One of: DRAIN, DOWN, RESUME.")
        reason: str = Field(
            default="operator-approved maintenance demo",
            description=(
                "Reason for DRAIN/DOWN. Use a clear maintenance reason; if the user "
                "does not provide one, use operator-approved maintenance demo."
            ),
        )

    class SetSlurmNodeStateTool(BaseTool):
        name: str = "set_slurm_node_state"
        description: str = (
            "Set a Slurm compute node state for a maintenance demo. Allowed nodes: "
            "cpu01, cpu02, cpu03. Allowed states: DRAIN, DOWN, RESUME. DRAIN and DOWN "
            "require a reason. This uses sudo scontrol update and then shows node state."
        )
        args_schema: type[BaseModel] = SetSlurmNodeStateInput

        def _run(
            self,
            node: str,
            state: str,
            reason: str = "operator-approved maintenance demo",
        ) -> str:
            return set_slurm_node_state(node, state, reason=reason)

    tools = [
        ReadConfigTool(),
        SafeInspectionCommandTool(),
        StageShellVariableChangeTool(),
        StageCommandProposalTool(),
        NodeSpackCheckTool(),
        NodeApptainerCheckTool(),
        SubmitSlurmSbatchDemoTool(),
        RunSlurmSrunDemoTool(),
        SlurmJobStatusTool(),
        SlurmDemoOutputTool(),
        CreateSharedSbatchDemoTool(),
        SubmitSharedSbatchDemoTool(),
        CreateSharedPythonSbatchTool(),
        SharedSlurmDemoOutputTool(),
        ShowSlurmNodeTool(),
        SetSlurmNodeStateTool(),
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
            "changes. For scalar config file changes, stage a proposal with "
            "stage_shell_variable_change instead of applying it. For /shared Slurm "
            "demo scripts, use the guarded shared sbatch tools when they match the "
            "request. For live commands, "
            "stage a command proposal instead of running it, except for the fixed "
            "safe Slurm demo tools, guarded Slurm node-state tools, and read-only "
            "inspection tools. Explain job IDs, node state changes, proposal paths, "
            "and validation commands the operator should run."
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
