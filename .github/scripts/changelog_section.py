#!/usr/bin/env python3
"""Print the CHANGELOG.md section that describes one release version.

The release workflow prepends this section to the GitHub-generated notes.
The generated part only lists merged PR titles, so a behaviour change that
makes users' threshold gates fail needs a hand-written summary to be visible.

A section starts with a level-2 heading that names the version, in any of
these forms, and runs until the next level-2 heading:

    ## 1.6.0
    ## v1.6.0
    ## [1.6.0] - 2026-10-11

Usage: changelog_section.py <version> [CHANGELOG.md]
Exits 1 with a message on stderr when the file or the section is missing.
"""

import re
import sys
from typing import Optional


def section(version: str, text: str) -> Optional[str]:
    heading = re.compile(r"^## \[?v?" + re.escape(version) + r"\]?(?:\s|$)")
    body: list[str] = []
    inside = False
    for line in text.splitlines():
        if line.startswith("## "):
            if inside:
                break
            inside = heading.match(line) is not None
            continue
        if inside:
            body.append(line)

    content = "\n".join(body).strip()
    if not inside or not content:
        return None
    return content + "\n"


def main() -> None:
    if len(sys.argv) not in (2, 3):
        sys.exit("Usage: changelog_section.py <version> [CHANGELOG.md]")
    version = sys.argv[1]
    path = sys.argv[2] if len(sys.argv) == 3 else "CHANGELOG.md"

    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except FileNotFoundError:
        sys.exit(f"{path} does not exist; add a '## {version}' section describing the release")

    found = section(version, text)
    if found is None:
        sys.exit(f"{path} has no '## {version}' section describing the release")
    sys.stdout.write(found)


if __name__ == "__main__":
    main()
