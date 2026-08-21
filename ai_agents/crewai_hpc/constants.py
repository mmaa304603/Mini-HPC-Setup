from __future__ import annotations

from pathlib import Path


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
    "squeue_me": ["bash", "-lc", "squeue -u \"$USER\""],
    "sacct_today": [
        "bash",
        "-lc",
        "sacct -u \"$USER\" --format=JobID,JobName,State,Elapsed,NodeList%20 -S today 2>/dev/null | tail -30",
    ],
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
