// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-complexity-backend",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        // Vapor web framework
        .package(url: "https://github.com/vapor/vapor.git", from: "4.99.0"),
        // v1.4.0. A version requirement is rejected by SwiftPM because swift-complexity
        // depends on the untagged indexstore-db, so the release commit is pinned instead.
        .package(
            url: "https://github.com/fummicc1/swift-complexity.git",
            revision: "25f4446f7eb0cb530bebbaaecaef37418c28f8b6"
        ),
    ],
    targets: [
        .executableTarget(
            name: "App",
            dependencies: [
                .product(name: "Vapor", package: "vapor"),
                .product(name: "SwiftComplexityCore", package: "swift-complexity")
            ]
        ),
        .testTarget(
            name: "AppTests",
            dependencies: [
                .target(name: "App"),
                .product(name: "XCTVapor", package: "vapor")
            ]
        )
    ]
)
