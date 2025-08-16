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
        // Validate mutually exclusive flags
        if cyclomaticOnly && cognitiveOnly {
            print("Error: --cyclomatic-only and --cognitive-only are mutually exclusive.")
            throw ExitCode.failure
        }

        if verbose {
            print("swift-complexity v\(Self.configuration.version)")
            print("Analyzing paths: \(paths.joined(separator: ", "))")
            print("Output format: \(format)")
            print("Recursive: \(recursive)")
            if !exclude.isEmpty {
                print("Exclude patterns: \(exclude.joined(separator: ", "))")
            }
            if let threshold = threshold {
                print("Complexity threshold: \(threshold)")
            }
        }

        // Execute analysis
        do {
            let analyzer = ComplexityAnalyzer()
            let fileProcessor = FileProcessor(analyzer: analyzer)

            let processingOptions = ProcessingOptions(
                recursive: recursive,
                excludePatterns: exclude,
                verbose: verbose
            )

            let results = try await fileProcessor.processFiles(
                at: paths, options: processingOptions)

            // Apply threshold filtering
            let filteredResults = filterByThreshold(results: results, threshold: threshold)

            // Generate output
            let outputOptions = OutputOptions(
                showCyclomaticOnly: cyclomaticOnly,
                showCognitiveOnly: cognitiveOnly,
                threshold: threshold
            )

            let formatter = OutputFormatter()
            let output = formatter.format(
                results: filteredResults, format: format, options: outputOptions)

            print(output)

            // Exit with warning code if threshold exceeded and results found
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

            guard !filteredFunctions.isEmpty else { return nil }

            return ComplexityResult(filePath: result.filePath, functions: filteredFunctions)
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
