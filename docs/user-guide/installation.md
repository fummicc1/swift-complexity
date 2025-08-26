# Installation Guide

## Prerequisites

- Swift 6.1 or later
- macOS 14 or later

## Installation Methods

### Option 1: Build from Source

```bash
git clone <repository-url>
cd swift-complexity
swift build --configuration release
```

The executable will be available at `.build/release/swift-complexity`.

### Option 2: Development Installation

For development or contributing:

```bash
git clone <repository-url>
cd swift-complexity
swift build
```

Run with:

```bash
swift run swift-complexity [options]
```

## Verification

Verify installation:

```bash
swift run swift-complexity --version
```

Or if using release build:

```bash
.build/release/swift-complexity --version
```

## Troubleshooting

### Common Issues

**Swift version compatibility**
- Ensure you're using Swift 6.1 or later
- Check with: `swift --version`

**Build failures**
- Clean build directory: `rm -rf .build`
- Rebuild: `swift build`

**Permission issues**
- Ensure you have read access to analyzed files
- Check file permissions with: `ls -la`