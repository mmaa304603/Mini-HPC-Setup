from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import Iterable

from .constants import REPO_ROOT
from .crewai_modes import run_chat, run_crewai, run_ops_chat
from .environment import check_environment
from .node_checks import check_node_apptainer, check_node_spack
from .proposals import apply_proposal
from .reports import dry_run_report, instantiate_crewai_proof
from .slurm_jobs import (
    create_shared_python_sbatch_script,
    create_shared_sbatch_demo_script,
    run_slurm_srun_demo,
    set_slurm_node_state,
    shared_slurm_demo_output,
    show_slurm_node,
    slurm_demo_output,
    slurm_job_status,
    submit_shared_sbatch_demo_script,
    submit_slurm_sbatch_demo,
)


def parse_args(argv: Iterable[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="CrewAI Mini HPC agent")
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
    mode.add_argument(
        "--submit-slurm-sbatch-demo",
        action="store_true",
        help="submit a fixed safe Slurm sbatch demo job",
    )
    mode.add_argument(
        "--create-shared-sbatch-demo",
        action="store_true",
        help="create a fixed safe Slurm sbatch demo script under /shared",
    )
    mode.add_argument(
        "--create-shared-python-sbatch",
        action="store_true",
        help="create a /shared Slurm sbatch script that runs a /shared Python script",
    )
    mode.add_argument(
        "--submit-shared-sbatch-demo",
        action="store_true",
        help="submit a fixed safe Slurm sbatch demo script from /shared",
    )
    mode.add_argument(
        "--run-slurm-srun-demo",
        action="store_true",
        help="run a fixed safe Slurm srun demo command",
    )
    mode.add_argument(
        "--slurm-job-status",
        nargs="?",
        const="",
        metavar="JOBID",
        help="show Slurm queue/accounting for a job ID, or current user if omitted",
    )
    mode.add_argument(
        "--slurm-demo-output",
        metavar="JOBID",
        help="print /tmp/crewai-slurm-demo-JOBID.out",
    )
    mode.add_argument(
        "--shared-slurm-demo-output",
        metavar="JOBID",
        help="print /shared/crewai-slurm-demo-JOBID.out",
    )
    mode.add_argument(
        "--set-slurm-node-state",
        nargs=2,
        metavar=("NODE", "STATE"),
        help="set cpu01-cpu03 Slurm node state to DRAIN, DOWN, or RESUME",
    )
    mode.add_argument(
        "--show-slurm-node",
        nargs="?",
        const="",
        metavar="NODE",
        help="show sinfo -N, or scontrol show node NODE if provided",
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
        default="ai_agents/crewai_hpc/crewai_hpc_evidence.md",
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
    parser.add_argument(
        "--nodes",
        type=int,
        default=1,
        help="node count for fixed Slurm demo jobs",
    )
    parser.add_argument(
        "--ntasks",
        type=int,
        default=1,
        help="task count for fixed Slurm demo jobs",
    )
    parser.add_argument(
        "--sleep-seconds",
        type=int,
        default=45,
        help="sleep duration for fixed Slurm demo jobs",
    )
    parser.add_argument(
        "--script-name",
        default="test_script_aug19.sbatch",
        help="simple .sbatch filename for /shared fixed demo script",
    )
    parser.add_argument(
        "--python-script",
        default="script.py",
        help="simple .py filename under /shared for --create-shared-python-sbatch",
    )
    parser.add_argument(
        "--reason",
        default="operator-approved maintenance demo",
        help="reason for Slurm DRAIN/DOWN state changes",
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
    if args.submit_slurm_sbatch_demo:
        print(
            submit_slurm_sbatch_demo(
                sleep_seconds=args.sleep_seconds,
                nodes=args.nodes,
                ntasks=args.ntasks,
            )
        )
        return 0
    if args.create_shared_sbatch_demo:
        print(
            create_shared_sbatch_demo_script(
                script_name=args.script_name,
                sleep_seconds=args.sleep_seconds,
                nodes=args.nodes,
                ntasks=args.ntasks,
            )
        )
        return 0
    if args.create_shared_python_sbatch:
        print(
            create_shared_python_sbatch_script(
                script_name=args.script_name,
                python_script=args.python_script,
                sleep_seconds=args.sleep_seconds,
                nodes=args.nodes,
                ntasks=args.ntasks,
            )
        )
        return 0
    if args.submit_shared_sbatch_demo:
        print(submit_shared_sbatch_demo_script(script_name=args.script_name))
        return 0
    if args.run_slurm_srun_demo:
        print(
            run_slurm_srun_demo(
                nodes=args.nodes,
                ntasks=args.ntasks,
                sleep_seconds=args.sleep_seconds,
                timeout=args.node_timeout,
            )
        )
        return 0
    if args.slurm_job_status is not None:
        print(slurm_job_status(args.slurm_job_status or None))
        return 0
    if args.slurm_demo_output:
        print(slurm_demo_output(args.slurm_demo_output))
        return 0
    if args.shared_slurm_demo_output:
        print(shared_slurm_demo_output(args.shared_slurm_demo_output))
        return 0
    if args.set_slurm_node_state:
        node, state = args.set_slurm_node_state
        print(set_slurm_node_state(node, state, reason=args.reason))
        return 0
    if args.show_slurm_node is not None:
        print(show_slurm_node(args.show_slurm_node or None))
        return 0
    if args.use_crewai:
        run_crewai(output_path, args.model)
        print("Wrote CrewAI evidence report:", output_path)
        return 0

    return 2


if __name__ == "__main__":
    raise SystemExit(main())
