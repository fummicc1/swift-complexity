# Usage Guide

## Basic Usage

### Analyze a Single File

```bash
swift run SwiftComplexity path/to/YourFile.swift
```

### Analyze a Directory

```bash
swift run SwiftComplexity path/to/directory
```

### Recursive Directory Analysis

```bash
swift run SwiftComplexity path/to/directory --recursive
```

## Command Line Options

### Required Arguments

- `<paths>` - Swift files or directories to analyze

### Output Options

- `--format <format>` - Output format: `text`, `json`, `xml` (default: `text`)
- `--verbose` - Show detailed analysis information

### Analysis Options

- `--threshold <number>` - Set complexity threshold for warnings
- `--config <path>` - Path to a per-type threshold config file (YAML). Defaults to `.swift-complexity.yml` in the current directory if present
- `--cyclomatic-only` - Show only cyclomatic complexity metrics
- `--cognitive-only` - Show only cognitive complexity metrics
- `--recursive` - Recursively analyze subdirectories

### Filtering Options

- `--exclude <patterns>` - Exclude files matching glob patterns

## Examples

### Basic Analysis

```bash
# Analyze current directory
swift run swift-complexity .

# Analyze specific file with verbose output
swift run swift-complexity Sources/MyFile.swift --verbose
```

### Output Formats

```bash
# JSON output for tool integration
swift run swift-complexity Sources --format json > complexity.json

# XML output for reporting tools
swift run swift-complexity Sources --format xml > complexity.xml
```

### Filtering and Thresholds

```bash
# Set complexity threshold
swift run swift-complexity Sources --threshold 10

# Exclude test files
swift run swift-complexity Sources --exclude "*Test*.swift" "*Mock*.swift"

# Recursive analysis excluding build directory
swift run swift-complexity . --recursive --exclude ".build/*"
```

### Specific Metrics

```bash
# Only cyclomatic complexity
swift run swift-complexity Sources --cyclomatic-only

# Only cognitive complexity
swift run swift-complexity Sources --cognitive-only
```

## Per-Type Complexity Thresholds

Different layers and features often warrant different complexity budgets. You can
assign thresholds per nominal type (class/struct/enum/actor, and extensions) using
a YAML configuration file. The tool reads `.swift-complexity.yml` from the current
directory automatically, or you can pass an explicit path with `--config`.

```yaml
# .swift-complexity.yml
defaultThreshold: 10            # Fallback for types that match no rule (optional)
rules:
  - prefix: Toilet              # Feature grouping (matches type name prefix)
    threshold: 12
  - prefix: User
    threshold: 8
  - suffix: Repository          # Layer grouping (matches type name suffix)
    threshold: 5
  - suffix: UseCase
    threshold: 15
```

### How a threshold is resolved

For each function, the effective threshold is resolved from its nearest enclosing
type name:

1. Collect every rule whose `prefix` and/or `suffix` matches the type name (a rule
   with both must match both).
2. If any rules match, the **strictest (lowest)** threshold wins. For example,
   `ToiletRepository` matches `prefix: Toilet` (12) and `suffix: Repository` (5),
   so its threshold is **5**.
3. If no rule matches (or the function is a free/top-level function), fall back to
   `--threshold` if provided, otherwise `defaultThreshold`. The CLI `--threshold`
   overrides `defaultThreshold`.

A function is flagged when either its cyclomatic or cognitive complexity reaches
the effective threshold. When a config (or `--threshold`) is active, only flagged
functions are shown and the tool exits with code `1` if any function is flagged.

```bash
# Auto-discovers .swift-complexity.yml in the current directory
swift run swift-complexity Sources --recursive

# Or point at a specific config file
swift run swift-complexity Sources --recursive --config config/complexity.yml
```

### Complex Examples

```bash
# Comprehensive project analysis
swift run swift-complexity Sources Tests \
  --recursive \
  --format json \
  --threshold 15 \
  --exclude "*Generated*" "*.pb.swift" \
  --verbose

# Quick complexity check for pull requests
swift run swift-complexity $(git diff --name-only HEAD~1 | grep "\.swift$")
```

## Integration with Build Systems

### Xcode Build Phase

Add a "Run Script" build phase:

```bash
if which swift-complexity >/dev/null; then
  swift-complexity Sources --threshold 10
else
  echo "warning: swift-complexity not found"
fi
```

### GitHub Actions

```yaml
- name: Check Code Complexity
  run: |
    swift run swift-complexity Sources Tests \
      --recursive \
      --format json \
      --threshold 15 > complexity-report.json
```

### Makefile

```makefile
complexity:
	swift run swift-complexity Sources --recursive --threshold 10

complexity-report:
	swift run swift-complexity Sources --format json > complexity-report.json
```

## Exit Codes

- `0` - Success
- `1` - Analysis completed with warnings (threshold exceeded)
- `2` - Error in command line arguments
- `3` - File access or parsing errors