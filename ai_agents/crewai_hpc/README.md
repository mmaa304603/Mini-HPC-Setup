# CrewAI Mini HPC Agent

This folder is an artifact for using CrewAI as an AI agent
workflow for Mini HPC setup/configuration/management.

## Objective

Use a CrewAI multi-agent workflow to audit one HPC management objective:
configuration readiness across Slurm, Warewulf, network, security, and
monitoring files.

## Agents

- `Mini HPC Cluster Configuration Auditor`
- `HPC Operations Reliability Reviewer`
- `Technical Documentation Reviewer`

## Version and Environment Requirements

Required:

- Python 3.10 or newer for live CrewAI runs.
- `crewai[tools]>=0.150.0`, installed from `requirements.txt`.
- An LLM API key for live agent modes. Set at least one provider key supported by the selected CrewAI model.
- SQLite 3.35.0 or newer for CrewAI/ChromaDB storage, or install `pysqlite3` so the local compatibility workaround can replace the standard `sqlite3` module.

Environment variables:

- `OPENAI_API_KEY`: Required when using an OpenAI-backed CrewAI model.
- `ANTHROPIC_API_KEY`: Optional, only needed when using an Anthropic-backed model.
- `CREWAI_MODEL`: Optional model override. Defaults to `gpt-4o-mini`.
- `CREWAI_STORAGE_DIR`: Optional storage directory. Defaults to `.crewai_storage` at the repository root.
- `HPC_SUDO_PASSWORD`: Optional and only needed for guarded commands that require sudo on cluster nodes.

Cluster command requirements depend on the selected mode:

- Slurm inspection and job modes require commands such as `sinfo`, `scontrol`, `sbatch`, and `srun`.
- Warewulf inspection modes require `wwctl`.
- Spack checks require `spack`.
- Apptainer checks require `apptainer`.

Check local readiness with:

```bash
python3 ai_agents/crewai_hpc/hpc_crewai.py --check-env
```

## Live CrewAI Run

Current CrewAI releases require Python 3.10+ and an LLM API key. On a machine
with those available:

```bash
cd /home/jay/Mini-HPC-Setup
python3.11 -m venv .venv-crewai
source .venv-crewai/bin/activate
python -m pip install -r ai_agents/crewai_hpc/requirements.txt
export OPENAI_API_KEY="your-key-here"
python ai_agents/crewai_hpc/hpc_crewai.py --use-crewai \
  --output ai_agents/crewai_hpc/crewai_hpc_evidence.md
```

## Interactive Chat Agent

After activating the virtual environment and exporting `OPENAI_API_KEY`, start a
CrewAI-backed HPC chatbot:

```bash
python ai_agents/crewai_hpc/hpc_crewai.py --chat
```

To save the chat to a specific file:

```bash
python ai_agents/crewai_hpc/hpc_crewai.py --chat \
  --transcript ai_agents/crewai_hpc/transcripts/chat.txt
```

Example questions:

```text
What should I check before enabling Slurm on the compute nodes?
Do the Warewulf and Slurm node names match?
What are the next management tasks for the GPU node?
How should I explain this CrewAI workflow during a technical review?
```

## Guarded Operations Agent

Use this mode when you want the LLM to inspect configuration and stage
management changes:

```bash
python ai_agents/crewai_hpc/hpc_crewai.py --ops-chat
```

To save the operations transcript:

```bash
python ai_agents/crewai_hpc/hpc_crewai.py --ops-chat \
  --transcript ai_agents/crewai_hpc/transcripts/spack-ops.txt
```

The operations agent can:

- read approved config files for network, Warewulf, Slurm, Spack, and Apptainer,
- run approved read-only inspection commands such as `sinfo`, `wwctl node list`, `spack find`, and `apptainer --version`,
- run approved read-only compute-node Spack and Apptainer checks through `sudo wwctl ssh`,
- submit fixed safe Slurm demo jobs with `sbatch` or `srun`,
- create and submit a fixed safe `/shared/*.sbatch` Slurm demo script,
- create a guarded `/shared/*.sbatch` wrapper that runs a `/shared/*.py` script,
- check Slurm queue/accounting and read demo job output,
- show and change Slurm node state for `cpu01-cpu03` using guarded maintenance actions,
- stage scalar shell-variable config changes as JSON proposals,
- stage live command proposals without executing them.

It does not directly apply config changes during chat. To apply a staged scalar
config proposal after review:

```bash
python ai_agents/crewai_hpc/hpc_crewai.py --apply-proposal \
  ai_agents/crewai_hpc/change_proposals/proposal-name.json
```

Example operations prompts:

```text
Read the network config and propose changing the DHCP range start to 10.0.1.10.
Check whether Warewulf and Slurm node names are consistent.
Stage the Warewulf overlay build command I should run after node changes.
Inspect Slurm availability using a safe command.
Read the Spack config and summarize the configured root, compiler, packages, and module type.
Run the safe Spack compiler list inspection command.
Run the compute-node Spack version check on all CPU nodes.
Run the compute-node Spack profile check on cpu01.
Read the Apptainer config and summarize security, cache, bind path, GPU, and module settings.
Run the safe Apptainer version inspection command.
Run the compute-node Apptainer version check on all CPU nodes.
Run the compute-node Apptainer profile check on cpu01.
Submit a one-node Slurm sbatch demo job that sleeps for 45 seconds.
Create /shared/test_script_aug19.sbatch as a one-node Slurm demo script.
Create /shared/script.sbatch so it runs /shared/script.py with one node and one task.
Submit /shared/test_script_aug19.sbatch.
Check the status of my Slurm jobs.
Read the output for Slurm demo job JOBID.
Read the shared Slurm demo output for job JOBID.
Run a one-node Slurm srun demo command that sleeps for 10 seconds.
Show Slurm node state for cpu03.
Set cpu03 to DOWN for operator-approved maintenance demo.
Set cpu03 back to RESUME.
Stage a proposal to change MODULES_TYPE to lmod in the Spack config.
```

You can also run fixed Slurm job demos directly without the LLM:

```bash
python ai_agents/crewai_hpc/hpc_crewai.py --submit-slurm-sbatch-demo \
  --nodes 1 --ntasks 1 --sleep-seconds 45

python ai_agents/crewai_hpc/hpc_crewai.py --create-shared-sbatch-demo \
  --script-name test_script_aug19.sbatch --nodes 1 --ntasks 1 --sleep-seconds 45

python ai_agents/crewai_hpc/hpc_crewai.py --create-shared-python-sbatch \
  --script-name script.sbatch --python-script script.py \
  --nodes 1 --ntasks 1 --sleep-seconds 10

python ai_agents/crewai_hpc/hpc_crewai.py --submit-shared-sbatch-demo \
  --script-name test_script_aug19.sbatch

python ai_agents/crewai_hpc/hpc_crewai.py --slurm-job-status
python ai_agents/crewai_hpc/hpc_crewai.py --slurm-job-status JOBID
python ai_agents/crewai_hpc/hpc_crewai.py --slurm-demo-output JOBID
python ai_agents/crewai_hpc/hpc_crewai.py --shared-slurm-demo-output JOBID

python ai_agents/crewai_hpc/hpc_crewai.py --run-slurm-srun-demo \
  --nodes 1 --ntasks 1 --sleep-seconds 10 --node-timeout 120

export HPC_SUDO_PASSWORD="your-sudo-password"
python ai_agents/crewai_hpc/hpc_crewai.py --show-slurm-node cpu03
python ai_agents/crewai_hpc/hpc_crewai.py --set-slurm-node-state cpu03 DOWN \
  --reason "operator-approved maintenance demo"
python ai_agents/crewai_hpc/hpc_crewai.py --set-slurm-node-state cpu03 RESUME
unset HPC_SUDO_PASSWORD
```

You can also run the compute-node Spack and Apptainer checks directly without
the LLM. Use `--node-timeout 60` for a one-minute timeout:

```bash
export HPC_SUDO_PASSWORD="your-sudo-password"
python ai_agents/crewai_hpc/hpc_crewai.py --check-node-spack profile --node-timeout 60
python ai_agents/crewai_hpc/hpc_crewai.py --check-node-spack version --node-timeout 60
python ai_agents/crewai_hpc/hpc_crewai.py --check-node-spack find --node-timeout 60
python ai_agents/crewai_hpc/hpc_crewai.py --check-node-spack compiler_list --node-timeout 60
python ai_agents/crewai_hpc/hpc_crewai.py --check-node-apptainer profile --node-timeout 60
python ai_agents/crewai_hpc/hpc_crewai.py --check-node-apptainer version --node-timeout 60
python ai_agents/crewai_hpc/hpc_crewai.py --check-node-apptainer config --node-timeout 60
unset HPC_SUDO_PASSWORD
```

## Evidence Run On This Host

This host currently has Python 3.9 and no exported LLM API key, so the script
also supports a local dry run that generates the same evidence package without
claiming a live LLM run:

```bash
python3 ai_agents/crewai_hpc/hpc_crewai.py --check-env
python3 ai_agents/crewai_hpc/hpc_crewai.py --dry-run \
  --output ai_agents/crewai_hpc/crewai_hpc_evidence.md
```

If CrewAI is installed in a temporary path, you can also prove that CrewAI was
imported and used to instantiate `Agent`, `Task`, and `Crew` objects without
calling an external LLM:

```bash
PYTHONPATH=/tmp/codex-crewai-050 python3 \
  ai_agents/crewai_hpc/hpc_crewai.py --instantiate-proof \
  --output ai_agents/crewai_hpc/crewai_instantiation_proof.md
```

Show during review:

- this directory,
- the source file `hpc_crewai.py`,
- the generated `crewai_hpc_evidence.md`,
- the generated `crewai_instantiation_proof.md` if available,
- the terminal commands used to run it.
