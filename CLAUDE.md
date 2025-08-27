# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview 📊

swift-complexity is a CLI tool that analyzes Swift code complexity using SwiftSyntax, measuring both cyclomatic and cognitive complexity. The project is split into two targets for OSS distribution.

## Development Commands 🛠️

### Build & Run

- `swift build` - Build the executable
- `swift run swift-complexity` - Run the CLI tool  
- `swift run swift-complexity -- --help` - Show CLI help (note the `--` separator)

### Testing

- `swift test` - Run all tests
- `swift test --filter <test-name>` - Run specific test
- `swift test --parallel` - Run tests in parallel

### Code Quality

- `swift-format -ri Sources Tests` - Format code (auto-run by lefthook)
- `lefthook install` - Setup Git hooks
- `lefthook run pre-commit` - Manually run pre-commit hooks

### Package Management

- `swift package resolve` - Resolve dependencies
- `swift package update` - Update dependencies
- `swift package clean` - Clean build artifacts

## Architecture Structure 🏗️

### Dual Target Design

**SwiftComplexityCore** (Library):

- Reusable core functionality
- Importable by other projects
- Dependencies: swift-syntax, SwiftParser

**SwiftComplexityCLI** (Executable):

- CLI interface only
- Uses ArgumentParser
- Utilizes Core library

### Core Components

- **ComplexityAnalyzer**: Main analysis engine (Actor design)
- **CyclomaticComplexityCalculator**: Cyclomatic complexity calculation (SyntaxVisitor)
- **CognitiveComplexityCalculator**: Cognitive complexity calculation (considers nesting)
- **FunctionDetector**: Function/method detection (includes initializers, deinitializers, accessors)
- **FileProcessor**: File/directory processing (TaskGroup parallel processing)
- **OutputFormatter**: Three output formats (text/json/xml)

### Test Structure

- **SwiftComplexityCoreTests**: Fixture-based unit & integration tests
- **SwiftComplexityCLITests**: CLI-specific tests
- **Bundle.module**: Test fixture resources (8 files)

## Important Design Decisions 🎯

### ViewMode Consistency

- Use `.sourceAccurate` in SyntaxVisitor (consistency with formatted code)
- Unified `.sourceAccurate` for manual children exploration

### Access Control

- Core module: Calculator/Detector classes are internal
- Public API: Only Analyzer, FileProcessor, data models, OutputFormatter

### Error Handling

- FileProcessorError: File processing errors
- CLIError: CLI-specific errors
- Proper LocalizedError implementation

### Concurrency

- ComplexityAnalyzer: Actor design
- FileProcessor: TaskGroup parallel file processing
- Sendable protocol compliance (Swift 6 support)

## Development Rules 📝

### Commit Messages

- **Write in English**
- Focus on "why" rather than "what"
- Auto-formatting via lefthook swift-format

### Testing

- Always create tests for new features
- Place fixture files in `Tests/SwiftComplexityCoreTests/Fixtures/`
- Document expected values in comments

### Code Quality

- Auto-apply swift-format (pre-commit)
- Minimize public API surface
- Leverage protocol-based design