# Development Guide

## Prerequisites

- Swift 6.1+
- macOS 14+

## Development Setup

### 1. Clone and Build

```bash
git clone <repository-url>
cd swift-complexity
swift build
```

### 2. Code Formatting

This project uses `swift-format` for consistent code style via lefthook.

#### Setup lefthook

Install lefthook:
```bash
brew install lefthook
```

Install and configure hooks:
```bash
lefthook install
```

#### Manual formatting

```bash
# Install swift-format if not already installed
brew install swift-format

# Format all Swift files
swift-format -ri Sources Tests
```

### 3. Running Tests

```bash
swift test
```

### 4. Building and Running

```bash
# Build
swift build

# Run with arguments
swift run SwiftComplexity --help
swift run SwiftComplexity Sources/SwiftComplexity --verbose
```

## Code Style

- Line length: 100 characters
- Indentation: 4 spaces
- Follow the `.swift-format` configuration
- Code is automatically formatted on commit via pre-commit hooks

## Git Workflow

1. Install lefthook: `lefthook install`
2. Code changes are automatically formatted before commit via lefthook
3. Ensure all tests pass before pushing
4. Follow conventional commit messages

## Tools Configuration

- **swift-format**: Code formatting (`.swift-format`)
- **lefthook**: Git hooks management (`.lefthook.yml`)
- **Swift Package Manager**: Dependency management (`Package.swift`)

## Git Hooks

This project uses lefthook for Git hooks management. The configuration in `.lefthook.yml`:

- **pre-commit**: Automatically runs `swift-format -ri Sources Tests` on Swift file changes
- **stage_fixed**: Automatically stages formatted files
- **glob filtering**: Only runs on `*.swift` files