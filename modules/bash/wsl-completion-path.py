"""Print the PATH entries Bash should search for one command-name prefix on WSL."""

import os
import re
import sys
from concurrent.futures import ThreadPoolExecutor


def completion_path(prefix, path):
    # Include possible Readline case-insensitive and hyphen/underscore matches.
    prefix = prefix.casefold().replace("-", "_")
    entries = path.split(os.pathsep)
    drives = {p for p in entries if re.match(r"^/mnt/[a-z](?:/|$)", p)}

    def may_match(directory):
        try:
            with os.scandir(directory) as entries:
                return any(
                    entry.name.casefold().replace("-", "_").startswith(prefix)
                    for entry in entries
                )
        except (FileNotFoundError, NotADirectoryError):
            return False
        except OSError:
            return True  # Leave uncertain directories to Bash.

    with ThreadPoolExecutor(max_workers=8) as pool:
        skipped = {
            p for p, match in zip(drives, pool.map(may_match, drives)) if not match
        }
    return os.pathsep.join(p for p in entries if p not in skipped)


if __name__ == "__main__":
    # A final separator protects trailing newlines from shell command substitution.
    sys.stdout.buffer.write(os.fsencode(completion_path(*sys.argv[1:]) + os.pathsep))
