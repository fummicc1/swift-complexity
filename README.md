# swift-complexity

A command-line tool to analyze Swift code complexity and quality metrics using swift-syntax.

## Features

- **Multiple Complexity Metrics**: Supports cyclomatic and cognitive complexity analysis
- **Exit Code Integration**: Returns exit code 1 when complexity thresholds are exceeded, perfect for CI/CD pipelines
- **Multiple Output Formats**: Text, JSON, and XML output for different use cases
- **Flexible Analysis**: Single files, directories, or recursive directory analysis
- **Swift Syntax Based**: Uses `swift-syntax` for accurate Swift code parsing
- **Extensible Architecture**: Designed to support additional quality metrics in the future

## Quick Start

### Installation

```bash
git clone <repository-url>
cd swift-complexity
swift build -c release
```

### Basic Usage

```bash
# Analyze a single file
swift run swift-complexity path/to/file.swift

# Analyze a directory with threshold enforcement
swift run swift-complexity Sources --threshold 10

# JSON output for tooling integration
swift run swift-complexity Sources --format json --recursive
```

## CLI Integration

The tool returns exit code 1 when any function exceeds the specified complexity threshold, making it ideal for:
- **CI/CD Pipelines**: Fail builds when complexity thresholds are exceeded
- **Git Hooks**: Prevent commits with overly complex code
- **Code Quality Gates**: Enforce complexity standards across teams

```bash
# Example: Fail if any function has complexity > 15
swift run swift-complexity Sources --threshold 15 --recursive
# Exit code 0: All functions below threshold
# Exit code 1: One or more functions exceed threshold
```

## Supported Complexity Metrics

- **Cyclomatic Complexity**: Measures the number of linearly independent paths through code
- **Cognitive Complexity**: Measures how difficult code is for humans to understand

*Future metrics planned: LCOM, cohesion/coupling indicators*

## Documentation

- **[User Guide](docs/user-guide/)**: Installation, usage, and examples
- **[Complexity Metrics](docs/user-guide/complexity-metrics.md)**: Detailed metric explanations and examples
- **[Output Formats](docs/user-guide/output-formats.md)**: JSON, XML, and text format specifications
- **[Development Guide](docs/development/DEVELOPMENT.md)**: Setup for contributors

## Package Structure

This project uses a dual-target architecture:

- **SwiftComplexityCore**: Core analysis library (reusable)
- **SwiftComplexityCLI**: Command-line interface

## Usage Examples

```bash
# Analyze with verbose output
swift run swift-complexity Sources --verbose --recursive

# Exclude test files with pattern matching
swift run swift-complexity Sources --recursive --exclude "*Test*.swift"

# Show only cognitive complexity above threshold
swift run swift-complexity Sources --cognitive-only --threshold 5
```

## Output Example

```
File: Sources/ComplexityAnalyzer.swift
+------------------+----------+----------+
| Function/Method  | Cyclo.   | Cogn.    |
+------------------+----------+----------+
| analyzeFunction  |    3     |    2     |
| calculateTotal   |    5     |    7     |
+------------------+----------+----------+

Total: 2 functions, Average Cyclomatic: 4.0, Average Cognitive: 4.5
```

## Requirements

- Swift 6.1+
- macOS 14+ or Linux (Ubuntu 22.04+)

## License

MIT License