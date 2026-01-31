import ArgumentParser
import Foundation
import SwiftComplexityCore

// MARK: - ArgumentParser Extensions

extension OutputFormat: ExpressibleByArgument {
    // ArgumentParser help is provided by the core module
}

// MARK: - CLI Errors

enum CLIError: Error, LocalizedError {
    case processingFailed(String)
    case unexpectedError(String)

    var errorDescription: String? {
        switch self {
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        case .unexpectedError(let message):
            return "Unexpected error: \(message)"
        }
    }
}

// MARK: - Main Command

@main
public struct ComplexityCommand: AsyncParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "swift-complexity",
        abstract: "Analyze Swift code complexity and quality metrics",
        discussion: """
            This tool analyzes Swift source code to calculate cyclomatic and cognitive complexity metrics.
            It can process individual files or entire directory trees recursively.
            """,
        version: "1.0.0"
    )

    // MARK: - Arguments

    @Argument(
        help: "Swift files or directories to analyze",
        completion: .file(extensions: ["swift"])
    )
    public var paths: [String]

    // MARK: - Options

    @Option(
        name: .shortAndLong,
        help: "Output format (\(OutputFormat.allValueStrings.joined(separator: ", ")))"
    )
    public var format: OutputFormat = .text

    @Option(
        name: .shortAndLong,
        help: "Complexity threshold for filtering results"
    )
    public var threshold: Int?

    @Flag(
        name: .long,
        help: "Show only cyclomatic complexity"
    )
    public var cyclomaticOnly: Bool = false

    @Flag(
        name: .long,
        help: "Show only cognitive complexity"
    )
    public var cognitiveOnly: Bool = false

    @Flag(
        name: .long,
        help: "Show LCOM4 class cohesion metrics"
    )
    public var lcom4: Bool = false

    @Option(
        name: .long,
        help: "IndexStore path for LCOM4 analysis (e.g., .build/debug/index/store)",
        completion: .directory
    )
    public var indexStorePath: String?

    @Option(
        name: .long,
        help: "Swift toolchain path for LCOM4 (required on Linux, optional on macOS)"
    )
    public var toolchainPath: String?

    @Flag(
        name: .shortAndLong,
        help: "Recursively analyze directories"
    )
    public var recursive: Bool = false

    @Option(
        name: .long,
        help: "Exclude file patterns (regex format)",
        completion: .file()
    )
    public var exclude: [String] = []

    @Flag(
        name: .shortAndLong,
        help: "Show verbose output"
    )
    public var verbose: Bool = false

    // MARK: - Execution

    public init() {}

    public func run() async throws {
        try validateFlags()
        try validateLCOM4Options()
        logVerboseConfiguration()

        do {
            let analyzer = try createAnalyzer()
            let fileProcessor = FileProcessor(analyzer: analyzer)

            let processingOptions = ProcessingOptions(
                recursive: recursive,
                excludePatterns: exclude,
                verbose: verbose
            )

            let results = try await fileProcessor.processFiles(
                at: paths, options: processingOptions)

            let filteredResults = filterByThreshold(results: results, threshold: threshold)

            let outputOptions = OutputOptions(
                showCyclomaticOnly: cyclomaticOnly,
                showCognitiveOnly: cognitiveOnly,
                showLCOM4: lcom4,
                threshold: threshold
            )

            let formatter = OutputFormatter()
            let output = formatter.format(
                results: filteredResults, format: format, options: outputOptions)

            print(output)

            if let threshold = threshold,
                hasExceededThreshold(results: results, threshold: threshold)
            {
                throw ExitCode(1)
            }

        } catch let error as FileProcessorError {
            throw CLIError.processingFailed(error.localizedDescription)
        } catch let error as CLIError {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        } catch {
            throw CLIError.unexpectedError(error.localizedDescription)
        }
    }

    /// Validates mutually exclusive flags
    private func validateFlags() throws {
        if cyclomaticOnly && cognitiveOnly {
            print("Error: --cyclomatic-only and --cognitive-only are mutually exclusive.")
            throw ExitCode.failure
        }
    }

    /// Validates LCOM4 options
    private func validateLCOM4Options() throws {
        if lcom4 && indexStorePath == nil {
            print("Error: --lcom4 requires --index-store-path option.")
            print(
                "Example: swift-complexity Sources --lcom4 --index-store-path .build/debug/index/store"
            )
            throw ExitCode.failure
        }

        #if os(Linux)
            if lcom4 && toolchainPath == nil {
                print("Error: --lcom4 requires --toolchain-path option on Linux.")
                print(
                    "Example: swift-complexity Sources --lcom4 --index-store-path .build/debug/index/store --toolchain-path ~/.local/share/swiftly/toolchains/swift-6.2"
                )
                throw ExitCode.failure
            }
        #endif
    }

    /// Logs verbose configuration
    private func logVerboseConfiguration() {
        guard verbose else { return }

        print("swift-complexity v\(Self.configuration.version)")
        print("Analyzing paths: \(paths.joined(separator: ", "))")
        print("Output format: \(format)")
        print("Recursive: \(recursive)")
        if lcom4 {
            print("LCOM4 analysis: enabled")
            if let path = indexStorePath { print("IndexStore path: \(path)") }
            if let path = toolchainPath { print("Toolchain path: \(path)") }
        }
        if !exclude.isEmpty { print("Exclude patterns: \(exclude.joined(separator: ", "))") }
        if let t = threshold { print("Complexity threshold: \(t)") }
    }

    /// Creates a ComplexityAnalyzer instance
    private func createAnalyzer() throws -> ComplexityAnalyzer {
        guard lcom4, let indexStorePath = indexStorePath else {
            return try ComplexityAnalyzer()
        }
        let toolchainURL = toolchainPath.map { URL(fileURLWithPath: $0) }
        return try ComplexityAnalyzer(
            indexStorePath: URL(fileURLWithPath: indexStorePath),
            toolchainPath: toolchainURL
        )
    }

    // MARK: - Private Methods

    private func filterByThreshold(results: [ComplexityResult], threshold: Int?)
        -> [ComplexityResult]
    {
        guard let threshold = threshold else { return results }

        return results.compactMap { result in
            let filteredFunctions = result.functions.filter { function in
                function.cyclomaticComplexity >= threshold
                    || function.cognitiveComplexity >= threshold
            }

            // For LCOM4, filter classes with low cohesion (LCOM4 >= 3)
            let filteredCohesions = result.classCohesions?.filter { cohesion in
                cohesion.lcom4 >= 3
            }

            // Keep result if either functions or cohesions pass threshold
            guard !filteredFunctions.isEmpty || filteredCohesions?.isEmpty == false else {
                return nil
            }

            return ComplexityResult(
                filePath: result.filePath,
                functions: filteredFunctions,
                classCohesions: filteredCohesions
            )
        }
    }

    private func hasExceededThreshold(results: [ComplexityResult], threshold: Int) -> Bool {
        for result in results {
            for function in result.functions {
                if function.cyclomaticComplexity >= threshold
                    || function.cognitiveComplexity >= threshold
                {
                    return true
                }
            }
        }
        return false
    }
}
