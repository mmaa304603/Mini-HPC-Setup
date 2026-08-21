from __future__ import annotations

import os
import platform
import sys

from .constants import REPO_ROOT


def apply_sqlite_workaround() -> str:
    """Use pysqlite3 when system sqlite is too old for ChromaDB/CrewAI."""
    try:
        import sqlite3

        version = tuple(int(part) for part in sqlite3.sqlite_version.split(".")[:3])
        if version >= (3, 35, 0):
            return "system sqlite3 {0}".format(sqlite3.sqlite_version)
    except Exception:
        pass

    try:
        import pysqlite3

        sys.modules["sqlite3"] = pysqlite3
        return "pysqlite3 workaround enabled"
    except ImportError:
        return "pysqlite3 not installed; ChromaDB may fail if sqlite3 < 3.35.0"

def configure_crewai_storage() -> str:
    storage_dir = REPO_ROOT / ".crewai_storage"
    storage_dir.mkdir(parents=True, exist_ok=True)
    os.environ.setdefault("CREWAI_STORAGE_DIR", str(storage_dir))
    return os.environ["CREWAI_STORAGE_DIR"]

def check_environment() -> int:
    print("Python:", platform.python_version())
    print("Executable:", sys.executable)
    print("OPENAI_API_KEY set:", bool(os.environ.get("OPENAI_API_KEY")))
    print("ANTHROPIC_API_KEY set:", bool(os.environ.get("ANTHROPIC_API_KEY")))
    print("SQLite status:", apply_sqlite_workaround())
    print("CrewAI storage:", configure_crewai_storage())
    try:
        import crewai  # type: ignore

        print("CrewAI installed:", getattr(crewai, "__version__", "version unknown"))
    except Exception as exc:  # pragma: no cover - evidence command
        print("CrewAI installed: no ({0})".format(exc.__class__.__name__))
    return 0
