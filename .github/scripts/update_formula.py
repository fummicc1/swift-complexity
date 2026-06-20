#!/usr/bin/env python3
"""Bump version and per-architecture sha256 values in a Homebrew formula.

The swift-complexity tap formulae use multi-arch ``on_macos``/``on_linux`` blocks,
so we cannot rely on a single ``url``/``sha256`` pair. Instead we anchor on each
release ``url`` line (which encodes the product and platform variant) and rewrite
the ``sha256`` line that immediately follows it, fetching the canonical checksum
from the ``.sha256`` asset uploaded alongside every tarball.

Usage: update_formula.py <version> <formula.rb>
"""

import re
import sys
import urllib.request

RELEASE_BASE = "https://github.com/fummicc1/swift-complexity/releases/download"

# Captures e.g. "SwiftComplexityCLI" and "macos-arm64" from a url line that uses
# the formula's `#{version}` interpolation, so the regex is version-independent.
URL_RE = re.compile(r"(SwiftComplexity\w+)-#\{version\}-([\w-]+)\.tar\.gz\"")
VERSION_RE = re.compile(r'version "[^"]*"')
SHA_RE = re.compile(r'sha256 "[^"]*"')


def fetch_sha256(version: str, product: str, variant: str) -> str:
    url = f"{RELEASE_BASE}/v{version}/{product}-{version}-{variant}.tar.gz.sha256"
    with urllib.request.urlopen(url) as response:
        # ".sha256" files are "<digest>  <filename>"; we only need the digest.
        return response.read().decode().split()[0]


def update(version: str, path: str) -> None:
    with open(path, encoding="utf-8") as f:
        lines = f.readlines()

    pending: tuple[str, str] | None = None
    out: list[str] = []
    for line in lines:
        if VERSION_RE.search(line) and line.lstrip().startswith("version "):
            line = VERSION_RE.sub(f'version "{version}"', line)

        match = URL_RE.search(line)
        if match:
            pending = (match.group(1), match.group(2))
        elif pending is not None and "sha256" in line:
            sha = fetch_sha256(version, *pending)
            line = SHA_RE.sub(f'sha256 "{sha}"', line)
            pending = None

        out.append(line)

    with open(path, "w", encoding="utf-8") as f:
        f.writelines(out)


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit("Usage: update_formula.py <version> <formula.rb>")
    update(sys.argv[1], sys.argv[2])


if __name__ == "__main__":
    main()
