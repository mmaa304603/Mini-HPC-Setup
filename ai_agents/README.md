# AI Agents

## Purpose

`ai_agents/` contains agent-oriented automation for the Mini HPC setup. Code in this directory is responsible for reasoning about cluster setup, orchestration, diagnostics, and repeatable operations that can be delegated to AI-assisted workflows.

## Directory Specification

- `crewai_hpc/`: CrewAI-based multi-agent workflow for HPC setup and operations.
- Additional agent implementations must be placed in their own subdirectory under `ai_agents/`.
- Shared utilities may be added under `ai_agents/common/` only when they are used by more than one agent implementation.

## Required Structure For New Agents

Each agent subdirectory must include:

- `README.md`: Purpose, inputs, outputs, setup, and run instructions.
- Source files for the agent workflow.
- Configuration files required by the workflow.
- Tests or validation scripts when behavior can be checked locally.

## Required Environment

Agent subdirectories must document their runtime requirements explicitly. At minimum, each implementation README must specify:

- Supported Python version.
- Required Python packages and minimum versions.
- Required operating-system commands.
- Required services, such as Slurm or Warewulf.
- Required environment variables.
- Optional environment variables and their defaults.

For Python-based agents, prefer a dedicated virtual environment and a dependency manifest such as `requirements.txt` or `pyproject.toml`.
