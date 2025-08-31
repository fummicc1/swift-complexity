import Foundation
import PackagePlugin

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

        // Build command arguments  
        var arguments: [String] = [
            "--format", "xcode",  // Use Xcode diagnostics format
            "--recursive",
        ]

        // Add threshold from environment or default
        let threshold = ProcessInfo.processInfo.environment["SWIFT_COMPLEXITY_THRESHOLD"] ?? "10"
        arguments.append(contentsOf: ["--threshold", threshold])

        // Add target directory instead of individual files to utilize recursive option
        arguments.append(sourceTarget.directoryURL.path)

        // Create the build command
        // Note: prebuildCommand cannot use executables built from source
        let command = Command.buildCommand(
            displayName: "Analyzing Swift complexity for \(target.name)",
            executable: swiftComplexityTool.url,
            arguments: arguments,
            inputFiles: inputFiles.map { $0.url },
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

            // Build command arguments
            var arguments: [String] = [
                "--format", "xcode",  // Use Xcode diagnostics format
            ]

            // Add threshold from build settings or default
            let threshold = "10"  // Could be extracted from Xcode build settings if needed
            arguments.append(contentsOf: ["--threshold", threshold])

            // Add input file paths
            arguments.append(contentsOf: inputFiles.map { $0.url.path })

            // Create the build command
            // Note: prebuildCommand cannot use executables built from source  
            let command = Command.buildCommand(
                displayName: "Analyzing Swift complexity for Xcode target \(target.displayName)",
                executable: swiftComplexityTool.url,
                arguments: arguments,
                inputFiles: inputFiles.map { $0.url },
                outputFiles: []  // No output files as we're using stdout for diagnostics
            )

            return [command]
        }
    }
#endif