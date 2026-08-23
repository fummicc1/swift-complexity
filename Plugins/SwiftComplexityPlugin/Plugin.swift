import Foundation
import PackagePlugin

/// Locates the shared configuration file and decides threshold arguments so
/// that plugin builds resolve thresholds exactly like direct CLI runs.
enum ConfigDiscovery {
    /// Keep candidates and their order in sync with
    /// `ThresholdConfiguration.discover` in SwiftComplexityCore, which plugin
    /// targets cannot import.
    static let configFileNames = [".swift-complexity.yml", ".swift-complexity.yaml"]

    static func configFile(inRoot root: URL) -> URL? {
        for name in configFileNames {
            let candidate = root.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    /// An explicit `SWIFT_COMPLEXITY_THRESHOLD` always wins; otherwise a
    /// discovered config file resolves thresholds on its own, and the
    /// historical default of 10 applies only when neither exists.
    static func thresholdArguments(configFound: Bool, environmentThreshold: String?) -> [String] {
        if let environmentThreshold, !environmentThreshold.isEmpty {
            return ["--threshold", environmentThreshold]
        }
        return configFound ? [] : ["--threshold", "10"]
    }

    static func arguments(configURL: URL?, environmentThreshold: String?) -> [String] {
        var arguments: [String] = []
        if let configURL {
            arguments.append(contentsOf: ["--config", configURL.path])
        }
        arguments.append(
            contentsOf: thresholdArguments(
                configFound: configURL != nil, environmentThreshold: environmentThreshold))
        return arguments
    }
}

@main
struct SwiftComplexityPlugin: BuildToolPlugin {
    /// Main entry point for the build tool plugin
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        // Get the SwiftComplexityCLI executable
        let swiftComplexityTool = try context.tool(named: "SwiftComplexityCLI")

        // Only process source targets
        guard let sourceTarget = target as? SourceModuleTarget else {
            return []
        }

        // Find all Swift source files in the target
        let inputFiles = sourceTarget.sourceFiles.filter { $0.url.pathExtension == "swift" }

        // If no Swift files, nothing to do
        guard !inputFiles.isEmpty else {
            return []
        }

        let configURL = ConfigDiscovery.configFile(inRoot: context.package.directoryURL)

        // Build command arguments
        var arguments: [String] = [
            "--format", "xcode",  // Use Xcode diagnostics format
            "--recursive",
        ]
        arguments.append(
            contentsOf: ConfigDiscovery.arguments(
                configURL: configURL,
                environmentThreshold: ProcessInfo.processInfo
                    .environment["SWIFT_COMPLEXITY_THRESHOLD"]))

        // Add target directory instead of individual files to utilize recursive option
        arguments.append(sourceTarget.directoryURL.path)

        // Declaring the config file as an input re-runs the analysis when it
        // changes and grants the sandboxed command read access to it.
        var commandInputFiles = inputFiles.map { $0.url }
        if let configURL {
            commandInputFiles.append(configURL)
        }

        // Create the build command
        // Note: prebuildCommand cannot use executables built from source
        let command = Command.buildCommand(
            displayName: "Analyzing Swift complexity for \(target.name)",
            executable: swiftComplexityTool.url,
            arguments: arguments,
            inputFiles: commandInputFiles,
            outputFiles: []  // No output files as we're using stdout for diagnostics
        )

        return [command]
    }
}

// MARK: - Xcode Support

#if canImport(XcodeProjectPlugin)
    import XcodeProjectPlugin

    extension SwiftComplexityPlugin: XcodeBuildToolPlugin {
        func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws
            -> [Command]
        {
            // Get the SwiftComplexityCLI executable
            let swiftComplexityTool = try context.tool(named: "SwiftComplexityCLI")

            // Find Swift source files
            let inputFiles = target.inputFiles.filter { $0.url.pathExtension == "swift" }

            // If no Swift files, nothing to do
            guard !inputFiles.isEmpty else {
                return []
            }

            let configURL = ConfigDiscovery.configFile(
                inRoot: context.xcodeProject.directoryURL)

            // Build command arguments
            var arguments: [String] = [
                "--format", "xcode"  // Use Xcode diagnostics format
            ]
            arguments.append(
                contentsOf: ConfigDiscovery.arguments(
                    configURL: configURL,
                    environmentThreshold: ProcessInfo.processInfo
                        .environment["SWIFT_COMPLEXITY_THRESHOLD"]))

            // Add input file paths
            arguments.append(contentsOf: inputFiles.map { $0.url.path })

            // Declaring the config file as an input re-runs the analysis when
            // it changes and grants the sandboxed command read access to it.
            var commandInputFiles = inputFiles.map { $0.url }
            if let configURL {
                commandInputFiles.append(configURL)
            }

            // Create the build command
            // Note: prebuildCommand cannot use executables built from source
            let command = Command.buildCommand(
                displayName: "Analyzing Swift complexity for Xcode target \(target.displayName)",
                executable: swiftComplexityTool.url,
                arguments: arguments,
                inputFiles: commandInputFiles,
                outputFiles: []  // No output files as we're using stdout for diagnostics
            )

            return [command]
        }
    }
#endif
