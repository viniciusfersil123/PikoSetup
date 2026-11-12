#!/usr/bin/env python3
"""Update a Git checkout or a GitHub ZIP copy of PikoSetup."""

from __future__ import annotations

import shutil
import subprocess
import sys
import tempfile
import urllib.request
import zipfile
from datetime import datetime
from pathlib import Path, PurePosixPath


ROOT = Path(__file__).resolve().parent
ARCHIVE_URL = "https://github.com/viniciusfersil123/PikoSetup/archive/refs/heads/main.zip"


def update_git_checkout() -> int:
    print("Updating Git checkout with git pull --ff-only…", flush=True)
    result = subprocess.run(["git", "pull", "--ff-only"], cwd=ROOT)
    if result.returncode == 0:
        print("PikoSetup is up to date.")
    return result.returncode


def update_zip_copy() -> int:
    print("Downloading the latest PikoSetup ZIP…", flush=True)
    with tempfile.TemporaryDirectory(prefix="pikosetup-update-") as temp_name:
        temp_dir = Path(temp_name)
        archive_path = temp_dir / "pikosetup.zip"
        request = urllib.request.Request(
            ARCHIVE_URL, headers={"User-Agent": "PikoSetup updater"}
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            archive_path.write_bytes(response.read())

        with zipfile.ZipFile(archive_path) as archive:
            members: list[tuple[zipfile.ZipInfo, Path]] = []
            for info in archive.infolist():
                parts = PurePosixPath(info.filename).parts
                if len(parts) < 2 or parts[0].startswith("PikoSetup-") is False:
                    continue
                relative = Path(*parts[1:])
                if relative.is_absolute() or ".." in relative.parts:
                    continue
                members.append((info, relative))
            if not members:
                raise RuntimeError("The downloaded ZIP did not contain PikoSetup files.")

            backup_root = ROOT / f".pikosetup-update-backup-{datetime.now():%Y%m%d-%H%M%S}"
            copied = 0
            for info, relative in members:
                if info.is_dir():
                    continue
                destination = ROOT / relative
                if destination.exists():
                    backup = backup_root / relative
                    backup.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(destination, backup)
                    copied += 1
                destination.parent.mkdir(parents=True, exist_ok=True)
                with archive.open(info) as source, destination.open("wb") as target:
                    shutil.copyfileobj(source, target)

        if copied:
            print(f"Previous versions of replaced files were saved in {backup_root}")
        print("PikoSetup ZIP copy updated. Restart PikoSetup to use the new version.")
    return 0


def main() -> int:
    if (ROOT / ".git").exists():
        return update_git_checkout()
    try:
        return update_zip_copy()
    except Exception as error:
        print(f"Update failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
