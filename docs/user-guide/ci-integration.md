# CI Integration

Set up a complexity gate for your Swift project in about 5 minutes using the
official GitHub Action, with violations shown as inline pull request
annotations via GitHub Code Scanning.

## Quick Start (GitHub Actions)

Create `.github/workflows/complexity.yml` in your repository:

```yaml
name: Complexity

on:
  pull_request:

permissions:
  contents: read
  security-events: write  # required by upload-sarif

jobs:
  complexity:
    runs-on: ubuntu-22.04
    steps:
      - uses: actions/checkout@v5

      - name: Analyze complexity
        id: analysis
        uses: fummicc1/swift-complexity@v1.2.0
        with:
          paths: Sources
          threshold: "10"

      - name: Upload SARIF to Code Scanning
        uses: github/codeql-action/upload-sarif@v3
        if: always()  # upload even when the threshold gate fails the job
        with:
          sarif_file: ${{ steps.analysis.outputs.report-file }}
```

That's it. Pull requests that introduce functions above the threshold now
fail the check, and each violation appears as an inline annotation on the
diff and in the repository's Security tab.

> **Note**: The action requires tag `v1.2.0` or later — earlier releases do
> not contain `action.yml`.

## Action Inputs

| Input | Default | Description |
| ----- | ------- | ----------- |
| `version` | `latest` | swift-complexity release to use (e.g. `1.2.0`), or `latest` |
| `paths` | `Sources` | Space-separated files/directories to analyze |
| `format` | `sarif` | Output format: `text`, `json`, `xml`, `xcode`, or `sarif` |
| `output-file` | `swift-complexity.sarif` | File the report is written to |
| `threshold` | `10` | Passed as `--threshold`; empty string omits it |
| `config` | (none) | Path to a `.swift-complexity.yml` threshold config |
| `fail-on-threshold` | `true` | Fail the step on exit code 1 (threshold exceeded) |
| `extra-args` | (none) | Additional CLI arguments, e.g. `--exclude Tests` |
| `github-token` | `${{ github.token }}` | Used to resolve `latest` via the GitHub API |

### Outputs

| Output | Description |
| ------ | ----------- |
| `report-file` | Path to the generated report |

## Notes and Pitfalls

- **A threshold is required for SARIF results.** Without `threshold` or a
  config file, the SARIF report contains no results (this mirrors the CLI's
  exit-code behavior). The action defaults to `10` so this works out of the
  box; pass an empty `threshold` only when your thresholds come from a
  `.swift-complexity.yml` config.
- **`fail-on-threshold: "false"` ignores exit code 1** (threshold exceeded)
  so the workflow can continue — useful for report-only setups. Exit codes
  other than 0 and 1 (real errors) always fail the step.
- **`if: always()` on the upload step** ensures the SARIF report reaches
  Code Scanning even when the analysis step fails the build.
- **Runner support**: macOS (arm64/x86_64) and Linux (x86_64). Linux arm64
  runners are not supported because no binary is published for them.
- Per-type thresholds, inline suppression comments, and LCOM4 analysis all
  work in CI exactly as they do locally — see the
  [Usage Guide](usage.md) for details.

## Without the Action (plain CLI)

If you prefer managing the binary yourself (or use a different CI system),
install via Homebrew or download a release binary directly:

```yaml
jobs:
  complexity:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v5

      - name: Install swift-complexity
        run: brew install fummicc1/tap/swift-complexity

      - name: Analyze
        run: |
          swift-complexity Sources --recursive \
            --format sarif --threshold 10 > swift-complexity.sarif

      - uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: swift-complexity.sarif
```

The tool exits with code 1 when any function exceeds its threshold, which
fails the job — the same gate the action provides.
