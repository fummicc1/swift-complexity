import Foundation
import MCP
import SwiftComplexityCore

/// Handles the `analyze_complexity` tool — analyzes Swift files/directories on disk.
enum AnalyzeComplexityHandler {
    static func handle(_ arguments: [String: Value]?) async -> CallTool.Result {
        // Extract required parameter
        guard let paths = ParamExtractor.stringArray("paths", from: arguments),
            !paths.isEmpty
        else {
            return .init(
                content: [
                    .text("Error: 'paths' parameter is required and must be a non-empty array")
                ],
                isError: true)
        }

        // Extract optional parameters
        let recursive = ParamExtractor.bool("recursive", from: arguments)
        let exclude = ParamExtractor.stringArray("exclude", from: arguments) ?? []
        let threshold = ParamExtractor.int("threshold", from: arguments)
        let formatString = ParamExtractor.string("format", from: arguments) ?? "json"
        let cyclomaticOnly = ParamExtractor.bool("cyclomatic_only", from: arguments)
        let cognitiveOnly = ParamExtractor.bool("cognitive_only", from: arguments)
        let lcom4 = ParamExtractor.bool("lcom4", from: arguments)
        let indexStorePath = ParamExtractor.string("index_store_path", from: arguments)
        let toolchainPath = ParamExtractor.string("toolchain_path", from: arguments)

        // Validate mutually exclusive flags
        if cyclomaticOnly && cognitiveOnly {
            return .init(
                content: [
                    .text("Error: 'cyclomatic_only' and 'cognitive_only' are mutually exclusive")
                ],
                isError: true)
        }

        // Validate LCOM4 options
        if lcom4 && indexStorePath == nil {
            return .init(
                content: [
                    .text("Error: 'index_store_path' is required when 'lcom4' is true")
                ],
                isError: true)
        }

        let format: OutputFormat = formatString == "text" ? .text : .json

        do {
            // Create analyzer
            let analyzer: ComplexityAnalyzer
            if lcom4, let indexStorePath = indexStorePath {
                let toolchainURL = toolchainPath.map { URL(fileURLWithPath: $0) }
                analyzer = try ComplexityAnalyzer(
                    indexStorePath: URL(fileURLWithPath: indexStorePath),
                    toolchainPath: toolchainURL
                )
            } else {
                analyzer = try ComplexityAnalyzer()
            }

            // Process files
            let fileProcessor = FileProcessor(analyzer: analyzer)
            let processingOptions = ProcessingOptions(
                recursive: recursive,
                excludePatterns: exclude,
                verbose: false
            )

            var results = try await fileProcessor.processFiles(
                at: paths, options: processingOptions)

            // Apply threshold filtering
            if let threshold = threshold {
                results = filterByThreshold(results: results, threshold: threshold)
            }

            // Format output
            let outputOptions = OutputOptions(
                showCyclomaticOnly: cyclomaticOnly,
                showCognitiveOnly: cognitiveOnly,
                showLCOM4: lcom4,
                threshold: threshold
            )

            let formatter = OutputFormatter()
            let output = formatter.format(results: results, format: format, options: outputOptions)

            return .init(content: [.text(output)], isError: false)

        } catch {
            return .init(content: [.text("Error: \(error.localizedDescription)")], isError: true)
        }
    }

    private static func filterByThreshold(results: [ComplexityResult], threshold: Int)
        -> [ComplexityResult]
    {
        results.compactMap { result in
            let filteredFunctions = result.functions.filter { function in
                function.cyclomaticComplexity >= threshold
                    || function.cognitiveComplexity >= threshold
            }

            let filteredCohesions = result.classCohesions?.filter { cohesion in
                cohesion.lcom4 >= 3
            }

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
}
