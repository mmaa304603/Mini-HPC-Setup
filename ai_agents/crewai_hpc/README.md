# CrewAI Mini HPC Agent Demo

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

## Live CrewAI Run

Current CrewAI releases require Python 3.10+ and an LLM API key. On a machine
with those available:

```bash
cd /home/jay/Mini-HPC-Setup_shell
python3.11 -m venv .venv-crewai
source .venv-crewai/bin/activate
python -m pip install -r ai_agents/crewai_hpc_demo/requirements.txt
export OPENAI_API_KEY="your-key-here"
python ai_agents/crewai_hpc_demo/hpc_crewai_demo.py --use-crewai \
  --output ai_agents/crewai_hpc_demo/crewai_hpc_evidence.md
```

## Interactive Chat Agent

After activating the virtual environment and exporting `OPENAI_API_KEY`, start a
CrewAI-backed HPC chatbot:

```bash
python ai_agents/crewai_hpc_demo/hpc_crewai_demo.py --chat
```

To save the chat to a specific file:

```bash
python ai_agents/crewai_hpc_demo/hpc_crewai_demo.py --chat \
  --transcript ai_agents/crewai_hpc_demo/transcripts/chat-demo.txt
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
python ai_agents/crewai_hpc_demo/hpc_crewai_demo.py --ops-chat
```

To save the operations transcript:

```bash
python ai_agents/crewai_hpc_demo/hpc_crewai_demo.py --ops-chat \
  --transcript ai_agents/crewai_hpc_demo/transcripts/spack-ops-demo.txt
```

The operations agent can:

- read approved config files for network, Warewulf, Slurm, Spack, and Apptainer,
- run approved read-only inspection commands such as `sinfo`, `wwctl node list`, `spack find`, and `apptainer --version`,
- run approved read-only compute-node Spack and Apptainer checks through `sudo wwctl ssh`,
- stage scalar shell-variable config changes as JSON proposals,
- stage live command proposals without executing them.

It does not directly apply config changes during chat. To apply a staged scalar
config proposal after review:

```bash
python ai_agents/crewai_hpc_demo/hpc_crewai_demo.py --apply-proposal \
  ai_agents/crewai_hpc_demo/change_proposals/proposal-name.json
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
Stage a proposal to change MODULES_TYPE to lmod in the Spack config.
```

You can also run the compute-node Spack and Apptainer checks directly without
the LLM. Use `--node-timeout 60` for a one-minute timeout:

```bash
export HPC_SUDO_PASSWORD="your-sudo-password"
python ai_agents/crewai_hpc_demo/hpc_crewai_demo.py --check-node-spack profile --node-timeout 60
python ai_agents/crewai_hpc_demo/hpc_crewai_demo.py --check-node-spack version --node-timeout 60
python ai_agents/crewai_hpc_demo/hpc_crewai_demo.py --check-node-spack find --node-timeout 60
python ai_agents/crewai_hpc_demo/hpc_crewai_demo.py --check-node-spack compiler_list --node-timeout 60
python ai_agents/crewai_hpc_demo/hpc_crewai_demo.py --check-node-apptainer profile --node-timeout 60
python ai_agents/crewai_hpc_demo/hpc_crewai_demo.py --check-node-apptainer version --node-timeout 60
python ai_agents/crewai_hpc_demo/hpc_crewai_demo.py --check-node-apptainer config --node-timeout 60
unset HPC_SUDO_PASSWORD
```

## Evidence Run On This Host

This host currently has Python 3.9 and no exported LLM API key, so the script
also supports a local dry run that generates the same evidence package without
claiming a live LLM run:

```bash
python3 ai_agents/crewai_hpc_demo/hpc_crewai_demo.py --check-env
python3 ai_agents/crewai_hpc_demo/hpc_crewai_demo.py --dry-run \
  --output ai_agents/crewai_hpc_demo/crewai_hpc_evidence.md
```

If CrewAI is installed in a temporary path, you can also prove that CrewAI was
imported and used to instantiate `Agent`, `Task`, and `Crew` objects without
calling an external LLM:

```bash
PYTHONPATH=/tmp/codex-crewai-050 python3 \
  ai_agents/crewai_hpc_demo/hpc_crewai_demo.py --instantiate-proof \
  --output ai_agents/crewai_hpc_demo/crewai_instantiation_proof.md
```

Show during review:

- this directory,
- the source file `hpc_crewai_demo.py`,
- the generated `crewai_hpc_evidence.md`,
- the generated `crewai_instantiation_proof.md` if available,
- the terminal commands used to run it.
