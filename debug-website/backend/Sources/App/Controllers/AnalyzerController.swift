import Vapor
import SwiftComplexityCore
import SwiftParser
import SwiftSyntax

struct AnalyzerController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let api = routes.grouped("api", "v1")

        api.post("analyze", use: analyze)
        api.post("batch-analyze", use: batchAnalyze)
        api.post("format", use: format)
    }

    // POST /api/v1/analyze
    // Analyzes a single Swift code snippet and optionally formats the result
    func analyze(req: Request) async throws -> Response {
        let request = try req.content.decode(AnalyzeRequest.self)

        // Parse Swift code using SwiftParser
        let sourceFile = Parser.parse(source: request.code)

        // Analyze complexity
        let analyzer = ComplexityAnalyzer()
        let result = try await analyzer.analyze(
            sourceFile: sourceFile,
            filePath: request.fileName
        )

        // If format is specified, return formatted output
        if let outputFormat = request.format {
            let formatter = OutputFormatter()
            let options = OutputOptions(
                showCyclomaticOnly: request.showCyclomaticOnly ?? false,
                showCognitiveOnly: request.showCognitiveOnly ?? false,
                threshold: request.threshold
            )

            let formatted = formatter.format(
                results: [result],
                format: outputFormat,
                options: options
            )

            let response = FormatResponse(formatted: formatted)
            return try await response.encodeResponse(for: req)
        }

        // Otherwise return raw ComplexityResult
        return try await result.encodeResponse(for: req)
    }

    // POST /api/v1/batch-analyze
    // Analyzes multiple Swift code files
    func batchAnalyze(req: Request) async throws -> BatchAnalyzeResponse {
        let request = try req.content.decode(BatchAnalyzeRequest.self)

        let analyzer = ComplexityAnalyzer()

        let results = try await withThrowingTaskGroup(of: ComplexityResult.self) { group in
            for file in request.files {
                group.addTask {
                    let sourceFile = Parser.parse(source: file.code)
                    return try await analyzer.analyze(
                        sourceFile: sourceFile,
                        filePath: file.path
                    )
                }
            }

            var allResults: [ComplexityResult] = []
            for try await result in group {
                allResults.append(result)
            }
            return allResults
        }

        return BatchAnalyzeResponse(results: results)
    }

    // POST /api/v1/format
    // Formats analysis results in different output formats
    func format(req: Request) async throws -> FormatResponse {
        let request = try req.content.decode(FormatRequest.self)

        let formatter = OutputFormatter()
        let options = OutputOptions(
            showCyclomaticOnly: request.showCyclomaticOnly ?? false,
            showCognitiveOnly: request.showCognitiveOnly ?? false,
            threshold: request.threshold
        )

        let formatted = formatter.format(
            results: request.results,
            format: request.format,
            options: options
        )

        return FormatResponse(formatted: formatted)
    }
}

// MARK: - Request/Response Models

struct AnalyzeRequest: Content {
    let code: String
    let fileName: String
    let format: OutputFormat?
    let showCyclomaticOnly: Bool?
    let showCognitiveOnly: Bool?
    let threshold: Int?
}

struct BatchAnalyzeRequest: Content {
    let files: [CodeFile]
}

struct CodeFile: Content {
    let code: String
    let path: String
}

struct BatchAnalyzeResponse: Content {
    let results: [ComplexityResult]
}

struct FormatRequest: Content {
    let results: [ComplexityResult]
    let format: OutputFormat
    let showCyclomaticOnly: Bool?
    let showCognitiveOnly: Bool?
    let threshold: Int?
}

struct FormatResponse: Content {
    let formatted: String
}
