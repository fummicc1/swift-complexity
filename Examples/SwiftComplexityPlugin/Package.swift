// swift-tools-version: 6.1
// Plugin package that depends on the main swift-complexity package

import PackageDescription

let package = Package(
    name: "SwiftComplexityPlugin",
    platforms: [
        .macOS(.v14),
        .iOS(.v13),
    ],
    products: [
        .plugin(
            name: "SwiftComplexityPlugin",
            targets: ["SwiftComplexityPlugin"]
        ),
    ],
    dependencies: [
        // Reference the main swift-complexity package
        .package(path: "../..")
    ],
    targets: [
        .plugin(
            name: "SwiftComplexityPlugin",
            capability: .buildTool(),
            dependencies: [
                .product(name: "SwiftComplexityCLI", package: "swift-complexity")
            ]
        ),
    ]
)