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
  traits: [
    // Off by default: Swift Package Index, Wasm, and a plain `swift build` on Linux
    // cannot pass the libdispatch include flags indexstore-db needs to compile.
    .trait(
      name: "IndexStore",
      description: "Index-backed analyses (LCOM4 cohesion, type coupling) via IndexStoreDB"
    )
  ],
  dependencies: [
    .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "600.0.0"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
    // IndexStore-DB integration (for LCOM4 semantic analysis)
    .package(url: "https://github.com/swiftlang/indexstore-db", branch: "main"),
    // MCP (Model Context Protocol) server SDK
    .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.11.0"),
    // YAML parser (for per-type complexity threshold configuration)
    .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0"),
  ],
  targets: [
    .target(
      name: "SwiftComplexityCore",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
        // IndexStore-DB integration (for LCOM4 semantic analysis)
        .product(
          name: "IndexStoreDB", package: "indexstore-db",
          condition: .when(traits: ["IndexStore"])),
        // YAML decoding for per-type threshold configuration
        .product(name: "Yams", package: "Yams"),
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
        .product(
          name: "IndexStoreDB", package: "indexstore-db",
          condition: .when(traits: ["IndexStore"])),
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
