---
description: Analyze Swift code complexity metrics (cyclomatic, cognitive, LCOM4). Use when asked to check code complexity, find complex functions, review code quality, or measure class cohesion in Swift projects.
---

# Swift Complexity Analysis

Use the `analyze_complexity` and `analyze_code_string` MCP tools from the swift-complexity server to analyze Swift code.

## When to use each tool

- **`analyze_complexity`**: When analyzing files or directories on disk. Supports recursive analysis, threshold filtering, and LCOM4 cohesion metrics.
- **`analyze_code_string`**: When analyzing a Swift code snippet directly without needing a file on disk.

## Workflow

1. Use `analyze_complexity` with `"format": "json"` for structured results
2. Identify functions with high complexity (cyclomatic >= 10 or cognitive >= 15 are common thresholds)
3. Provide actionable recommendations to reduce complexity (extract methods, simplify conditionals, use guard clauses)

## Interpreting results

- **Cyclomatic complexity**: Number of independent paths through code. Higher = more test cases needed.
- **Cognitive complexity**: How hard the code is to understand. Accounts for nesting depth.
- **LCOM4**: Class cohesion metric. 1 = cohesive, higher = consider splitting the class.

## Example usage

Analyze a directory recursively with a threshold:
```json
{
  "paths": ["Sources/"],
  "recursive": true,
  "threshold": 10,
  "format": "json"
}
```
