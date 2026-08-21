from __future__ import annotations

import json
import re
from datetime import datetime
from pathlib import Path
from typing import Tuple

from .constants import CONFIG_TARGETS, REPO_ROOT


def proposal_dir() -> Path:
    path = REPO_ROOT / "ai_agents" / "crewai_hpc" / "change_proposals"
    path.mkdir(parents=True, exist_ok=True)
    return path

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
