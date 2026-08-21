from __future__ import annotations

import re
from typing import Dict, List, Tuple

from .constants import REPO_ROOT, SOURCE_FILES


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
