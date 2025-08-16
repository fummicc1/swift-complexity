// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "swift-complexity",
  platforms: [
    .macOS(.v14)
  ],
  products: [
    .library(
      name: "SwiftComplexityCore",
      targets: ["SwiftComplexityCore"]
    ),
    .executable(
      name: "swift-complexity",
      targets: ["SwiftComplexityCLI"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/apple/swift-syntax.git", from: "600.0.0"),
    .package(url: "https://github.com/apple/swift-argument-parser", from: "1.0.0"),
  ],
  targets: [
    .target(
      name: "SwiftComplexityCore",
      dependencies: [
        .product(name: "SwiftSyntax", package: "swift-syntax"),
        .product(name: "SwiftParser", package: "swift-syntax"),
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
  ]
)
