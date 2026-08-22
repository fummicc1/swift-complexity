# Xcode Build Tool Plugin

`SwiftComplexityPlugin` runs the complexity analysis on every build and surfaces
violations as warnings and errors directly in Xcode's issue navigator, using the
same configuration and the same judgment as the CLI and CI.

## Requirements

- The package that applies the plugin must declare `// swift-tools-version: 6.0`
  or later. SwiftPM skips the analysis for older tools versions because the
  plugin's build command declares no output files.
- macOS 14 or later (inherited from swift-complexity's platform requirement).

## Setup

### Swift Package Manager

```swift
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "YourProject",
    dependencies: [
        .package(url: "https://github.com/fummicc1/swift-complexity.git", from: "1.4.0")
    ],
    targets: [
        .target(
            name: "YourTarget",
            plugins: [
                .plugin(name: "SwiftComplexityPlugin", package: "swift-complexity")
            ]
        )
    ]
)
```

### Xcode Project

1. Add the swift-complexity package to your Xcode project
2. In Build Phases, add "SwiftComplexityPlugin" to Run Build Tool Plug-ins

## Configuration

### `.swift-complexity.yml` discovery

The plugin looks for `.swift-complexity.yml` (then `.swift-complexity.yaml`) and
passes it to the analysis, so plugin builds resolve thresholds exactly like
`swift-complexity --config` runs:

- **SwiftPM builds**: at the package root (next to `Package.swift`)
- **Xcode project builds**: at the project root (next to `.xcodeproj`)

Editing the file re-triggers the analysis on the next build.

```yaml
defaultThreshold: 10
rules:
  - suffix: Repository
    threshold: 8
```

### Threshold precedence

| `SWIFT_COMPLEXITY_THRESHOLD` env | Config file | Effective behavior |
| --- | --- | --- |
| set | any | `--threshold <env>` — overrides the config's `defaultThreshold` for types no rule matches; per-type rules still win |
| not set | present | The config alone decides (`rules`, then `defaultThreshold`) |
| not set | absent | `--threshold 10` (historical default) |

A function is flagged when its cyclomatic or cognitive complexity **reaches** the
resolved threshold (`value >= threshold`), identically in the CLI exit code, SARIF,
and Xcode diagnostics. Warnings escalate to errors above twice the threshold.

## Limitations

- **Coupling and LCOM4 gates do not run in plugin builds** — they need an index
  store, which is not available inside a build tool command. Run them in CI
  instead (see [CI Integration](ci-integration.md)). If your config contains a
  `coupling:` block, the analysis prints a note to the build log saying the
  coupling gate is not active in this run; this is expected.
- Builds fail (`exit 1`) when a threshold violation exists, matching the CLI's
  gating behavior.
