// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swift-complexity",
  platforms: [
    .macOS(.v14),
    .iOS(.v13),
  ],
  products: [
    .library(
      name: "SwiftComplexityCore",
      targets: ["SwiftComplexityCore"]
    ),
    .executable(
      name: "SwiftComplexityCLI",
      targets: ["SwiftComplexityCLI"]
    ),
    .executable(
      name: "SwiftComplexityMCP",
      targets: ["SwiftComplexityMCP"]
    ),
    .plugin(
      name: "SwiftComplexityPlugin",
      targets: ["SwiftComplexityPlugin"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
    // IndexStore-DB integration (for LCOM4 semantic analysis)
    .package(url: "https://github.com/swiftlang/indexstore-db", branch: "main"),
    // MCP (Model Context Protocol) server SDK
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0"),
  ],
  targets: [
    .target(
      name: "SwiftComplexityCore",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
        // IndexStore-DB integration (for LCOM4 semantic analysis)
        .product(name: "IndexStoreDB", package: "indexstore-db"),
      ],
      path: "Sources/SwiftComplexityCore",
    ),
    .executableTarget(
      name: "SwiftComplexityCLI",
      dependencies: [
        "SwiftComplexityCore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      path: "Sources/SwiftComplexityCLI",
    ),
    .testTarget(
      name: "SwiftComplexityCoreTests",
      dependencies: [
        "SwiftComplexityCore",
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
      ],
      path: "Tests/SwiftComplexityCoreTests",
      resources: [
        .copy("Fixtures")
      ],
    ),
    .testTarget(
      name: "SwiftComplexityCLITests",
      dependencies: [
        "SwiftComplexityCLI",
        "SwiftComplexityCore",
      ],
      path: "Tests/SwiftComplexityCLITests",
    ),
    .executableTarget(
      name: "SwiftComplexityMCP",
      dependencies: [
        "SwiftComplexityCore",
        .product(name: "MCP", package: "swift-sdk"),
      ],
      path: "Sources/SwiftComplexityMCP"
    ),
    .plugin(
      name: "SwiftComplexityPlugin",
      capability: .buildTool(),
      dependencies: [
        "SwiftComplexityCLI"
      ]
    ),
    .testTarget(
      name: "SwiftComplexityMCPTests",
      dependencies: [
        "SwiftComplexityMCP",
        "SwiftComplexityCore",
      ],
      path: "Tests/SwiftComplexityMCPTests"
    ),
  ]
)
