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
        version: SwiftComplexityVersion.current
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

    @Option(
        name: .long,
        help:
            "Path to a per-type threshold config file (YAML). Defaults to .swift-complexity.yml in the current directory if present.",
        completion: .file(extensions: ["yml", "yaml"])
    )
    public var config: String?

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

    @Flag(
        name: .long,
        help: "Show type coupling metrics (fan-in, fan-out, instability)"
    )
    public var coupling: Bool = false

    @Option(
        name: .long,
        help: "IndexStore path for index-backed analysis (e.g., .build/debug/index/store)",
        completion: .directory
    )
    public var indexStorePath: String?

    @Option(
        name: .long,
        help:
            "Swift toolchain path for index-backed analysis (required on Linux, optional on macOS)"
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

    @Flag(
        name: .long,
        help:
            "Print every function or type with a // swift-complexity:disable comment, and its current metric values, to stderr"
    )
    public var reportSuppressions: Bool = false

    // MARK: - Execution

    public init() {}

    public func run() async throws {
        try validateFlags()
        try validateLCOM4Options()

        let configuration = try loadConfiguration()

        if format == .sarif, threshold == nil, configuration.isEmpty {
            FileHandle.standardError.write(
                Data(
                    "Warning: SARIF output contains no results unless a threshold is set via --threshold or a config file.\n"
                        .utf8))
        }

        // A configured coupling gate that never runs would pass CI silently,
        // e.g. when the --coupling flag is dropped from one job.
        if configuration.coupling != nil, !coupling {
            FileHandle.standardError.write(
                Data(
                    "Warning: coupling thresholds are configured but --coupling is not enabled, so they will not gate this run.\n"
                        .utf8))
        }

        logVerboseConfiguration(configuration: configuration)

        do {
            let analyzer = try createAnalyzer()
            let fileProcessor = FileProcessor(analyzer: analyzer)

            let processingOptions = ProcessingOptions(
                recursive: recursive,
                excludePatterns: exclude,
                verbose: verbose,
                couplingEnabled: coupling
            )

            let results = try await fileProcessor.processFiles(
                at: paths, options: processingOptions)

            if coupling, let diagnostics = await fileProcessor.lastCouplingDiagnostics {
                printCouplingDiagnostics(diagnostics)
            }

            if reportSuppressions {
                printSuppressionsReport(results: results)
            }

            let filteredResults = filterByThreshold(
                results: results, threshold: threshold, configuration: configuration)

            let outputOptions = OutputOptions(
                showCyclomaticOnly: cyclomaticOnly,
                showCognitiveOnly: cognitiveOnly,
                showLCOM4: lcom4,
                threshold: threshold,
                thresholdConfiguration: configuration
            )

            let formatter = OutputFormatter()
            let output = formatter.format(
                results: filteredResults, format: format, options: outputOptions)

            print(output)

            if threshold != nil || !configuration.isEmpty || configuration.coupling != nil,
                hasExceededThreshold(
                    results: results, threshold: threshold, configuration: configuration)
            {
                throw ExitCode(1)
            }

        } catch let exitCode as ExitCode {
            // Re-throw threshold/exit signals so ArgumentParser sets the exit code
            // without wrapping them into an "unexpected error" message.
            throw exitCode
        } catch let error as FileProcessorError {
            throw CLIError.processingFailed(error.localizedDescription)
        } catch let error as CLIError {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        } catch {
            throw CLIError.unexpectedError(error.localizedDescription)
        }
    }

    /// Loads per-type threshold configuration from `--config` if provided,
    /// otherwise auto-discovers `.swift-complexity.yml` in the current directory.
    private func loadConfiguration() throws -> ThresholdConfiguration {
        do {
            if let config {
                return try ThresholdConfiguration.load(fromFileAtPath: config)
            }
            return try ThresholdConfiguration.discover() ?? .empty
        } catch let error as ThresholdConfiguration.LoadError {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
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
        // Both index-backed analyses share the same prerequisites.
        let indexBackedFlag: String? = lcom4 ? "--lcom4" : (coupling ? "--coupling" : nil)
        guard let flag = indexBackedFlag else { return }

        #if !IndexStore
            print("Error: \(flag) is not available in this build.")
            print(
                "Rebuild with 'swift build --traits IndexStore' or install a release binary (Homebrew, GitHub Releases)."
            )
            throw ExitCode.failure
        #else
            if indexStorePath == nil {
                print("Error: \(flag) requires --index-store-path option.")
                print(
                    "Example: swift-complexity Sources \(flag) --index-store-path .build/debug/index/store"
                )
                throw ExitCode.failure
            }

            #if os(Linux)
                if toolchainPath == nil {
                    print("Error: \(flag) requires --toolchain-path option on Linux.")
                    print(
                        "Example: swift-complexity Sources \(flag) --index-store-path .build/debug/index/store --toolchain-path ~/.local/share/swiftly/toolchains/swift-6.2"
                    )
                    throw ExitCode.failure
                }
            #endif
        #endif
    }

    /// Logs verbose configuration
    private func logVerboseConfiguration(configuration: ThresholdConfiguration) {
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
        if !configuration.isEmpty {
            if let defaultThreshold = configuration.defaultThreshold {
                print("Per-type config default threshold: \(defaultThreshold)")
            }
            print("Per-type config rules: \(configuration.rules.count)")
        }
    }

    /// Creates a ComplexityAnalyzer instance
    private func createAnalyzer() throws -> ComplexityAnalyzer {
        guard lcom4 || coupling, let indexStorePath = indexStorePath else {
            return try ComplexityAnalyzer()
        }
        let toolchainURL = toolchainPath.map { URL(fileURLWithPath: $0) }
        // lcom4Enabled keeps cohesion fields out of coupling-only runs; the
        // index store itself is shared by both analyses.
        return try ComplexityAnalyzer(
            indexStorePath: URL(fileURLWithPath: indexStorePath),
            toolchainPath: toolchainURL,
            lcom4Enabled: lcom4
        )
    }

    // MARK: - Private Methods

    /// Prints every suppressed function and type with its current metric
    /// values to stderr, so `// swift-complexity:disable` comments stay
    /// visible instead of silently hiding violations.
    private func printSuppressionsReport(results: [ComplexityResult]) {
        var lines: [String] = []
        for result in results {
            for function in result.functions {
                guard let suppressed = function.suppressedMetrics, !suppressed.isEmpty else {
                    continue
                }
                let metricValues = suppressed.sorted { $0.rawValue < $1.rawValue }.compactMap {
                    metric -> String? in
                    switch metric {
                    case .cyclomatic:
                        return "cyclomatic (\(function.cyclomaticComplexity))"
                    case .cognitive:
                        return "cognitive (\(function.cognitiveComplexity))"
                    case .lcom4, .coupling:
                        return nil  // type-level metrics, never present on a function
                    }
                }
                lines.append(
                    "\(result.filePath):\(function.location.line): \(function.name) — \(metricValues.joined(separator: ", "))"
                )
            }
            for cohesion in result.classCohesions ?? [] {
                guard cohesion.isSuppressed(.lcom4) else { continue }
                lines.append(
                    "\(result.filePath):\(cohesion.location.line): \(cohesion.name) — lcom4 (\(cohesion.lcom4))"
                )
            }
            for coupling in result.typeCouplings ?? [] {
                guard coupling.isSuppressed(.coupling) else { continue }
                lines.append(
                    "\(result.filePath):\(coupling.location.line): \(coupling.name) — coupling (fan-in \(coupling.fanIn), fan-out \(coupling.fanOut))"
                )
            }
        }

        let header =
            lines.isEmpty
            ? "No suppressed complexity checks found.\n"
            : "Suppressed complexity checks:\n" + lines.map { "  \($0)" }.joined(separator: "\n")
                + "\n"
        FileHandle.standardError.write(Data(header.utf8))
    }

    private func filterByThreshold(
        results: [ComplexityResult],
        threshold: Int?,
        configuration: ThresholdConfiguration
    ) -> [ComplexityResult] {
        // No filtering when neither a global threshold nor any config rule is set.
        guard threshold != nil || !configuration.isEmpty else { return results }

        return results.compactMap { result in
            let filteredFunctions = result.functions.filter { function in
                configuration.isExceeded(function, fallback: threshold)
            }

            // For LCOM4, filter classes with low cohesion (LCOM4 >= 3),
            // excluding types whose cohesion check is suppressed inline
            let filteredCohesions = result.classCohesions?.filter { cohesion in
                cohesion.lcom4 >= 3 && !cohesion.isSuppressed(.lcom4)
            }

            guard
                !filteredFunctions.isEmpty || filteredCohesions?.isEmpty == false
                    || !(result.typeCouplings ?? []).isEmpty
            else {
                return nil
            }

            // Coupling metrics pass through unfiltered: they are ranking
            // context (Hotspots needs every type's fan-in) and report data,
            // not a violations list. Coupling violations gate through the
            // exit code and SARIF levels instead.
            return ComplexityResult(
                filePath: result.filePath,
                functions: filteredFunctions,
                classCohesions: filteredCohesions,
                typeCouplings: result.typeCouplings
            )
        }
    }

    private func hasExceededThreshold(
        results: [ComplexityResult],
        threshold: Int?,
        configuration: ThresholdConfiguration
    ) -> Bool {
        for result in results {
            for function in result.functions {
                if configuration.isExceeded(function, fallback: threshold) {
                    return true
                }
            }
            for coupling in result.typeCouplings ?? []
            where !configuration.couplingViolations(coupling).isEmpty {
                return true
            }
        }
        return false
    }

    /// One-line attribution summary to stderr (details with --verbose). The
    /// percentage covers project references only: stdlib/framework symbols
    /// are excluded by design, not lost.
    private func printCouplingDiagnostics(_ diagnostics: CouplingDiagnostics) {
        let projectRefs = diagnostics.attributedTotal + diagnostics.droppedUnattributable
        let percent = projectRefs == 0 ? 100 : diagnostics.attributedTotal * 100 / projectRefs
        var lines = [
            "coupling: \(diagnostics.refsTotal) refs (\(projectRefs) project), "
                + "\(percent)% attributed (containedBy \(diagnostics.attributedByContainedBy), "
                + "baseOf \(diagnostics.attributedByBaseOf), "
                + "location \(diagnostics.attributedByLocation)), "
                + "\(diagnostics.droppedUnattributable) unattributed"
        ]
        if verbose {
            lines.append("  external symbols: \(diagnostics.droppedNonProjectSymbol)")
            lines.append("  typealias refs:   \(diagnostics.droppedTypealias)")
            lines.append("  self references:  \(diagnostics.selfReferencesSkipped)")
        }
        FileHandle.standardError.write(Data((lines.joined(separator: "\n") + "\n").utf8))
    }
}
