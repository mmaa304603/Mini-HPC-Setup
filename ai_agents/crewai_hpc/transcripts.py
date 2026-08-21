from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import Any

from .constants import REPO_ROOT


def default_transcript_path(mode: str) -> Path:
    timestamp = datetime.now().astimezone().strftime("%Y%m%d-%H%M%S")
    path = REPO_ROOT / "ai_agents" / "crewai_hpc" / "transcripts"
    path.mkdir(parents=True, exist_ok=True)
    return path / "{0}-{1}.txt".format(mode, timestamp)

def append_transcript(path: Path, speaker: str, text: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write("\n## {0} {1}\n\n".format(speaker, datetime.now().astimezone().isoformat(timespec="seconds")))
        handle.write(str(text).strip())
        handle.write("\n")
