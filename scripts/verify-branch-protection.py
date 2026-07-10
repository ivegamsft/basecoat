"""Verify that branch protection settings were correctly restored after a publish run.

Usage: python verify-branch-protection.py <before_file> <after_file>

Exits with code 0 if the two JSON files are equal, 1 otherwise.
"""

import json
import sys


def main() -> None:
    if len(sys.argv) != 3:
        print("Usage: verify-branch-protection.py <before_file> <after_file>", file=sys.stderr)
        sys.exit(2)

    with open(sys.argv[1], encoding="utf-8") as before_file:
        before = json.load(before_file)
    with open(sys.argv[2], encoding="utf-8") as after_file:
        after = json.load(after_file)

    if before != after:
        print("Branch protection restore mismatch.", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
