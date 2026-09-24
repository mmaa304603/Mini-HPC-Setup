"""Content/ownership fingerprint for image publication (standard library only)."""
import hashlib
import json
import os
from pathlib import Path
import stat
import sys

# Runtime state and caches are not deployment inputs.
EXCLUDED = {"dev", "proc", "sys", "run", "tmp", "var/cache", "var/log",
            "etc/hpc-image-id"}

def fingerprint(root):
    root = Path(root)
    digest = hashlib.sha256()
    for directory, dirs, files in os.walk(root, followlinks=False):
        dirs[:] = sorted(d for d in dirs
                         if (Path(directory) / d).relative_to(root).as_posix() not in EXCLUDED)
        for name in sorted(dirs + files):
            path = Path(directory) / name
            relative = path.relative_to(root).as_posix()
            if relative in EXCLUDED:
                continue
            info = path.lstat()
            record = [relative, info.st_mode, info.st_uid, info.st_gid]
            digest.update(json.dumps(record, separators=(",", ":")).encode() + b"\0")
            if stat.S_ISLNK(info.st_mode):
                digest.update(os.readlink(path).encode() + b"\0")
            elif stat.S_ISREG(info.st_mode):
                with path.open("rb") as stream:
                    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
                        digest.update(chunk)
                digest.update(b"\0")
    return digest.hexdigest()

if __name__ == "__main__":
    print(fingerprint(sys.argv[1]))
