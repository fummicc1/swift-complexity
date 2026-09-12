import MCP
import SwiftComplexityCore
import SwiftParser

/// Handles the `analyze_code_string` tool — analyzes Swift code from a string directly.
enum AnalyzeCodeStringHandler {
    static func handle(_ arguments: [String: Value]?) async -> CallTool.Result {
        // Extract required parameter
        guard let code = ParamExtractor.string("code", from: arguments) else {
            return .init(
                content: [
                    .text(text: "Error: 'code' parameter is required", annotations: nil, _meta: nil)
                ],
                isError: true)
        }

        let fileName = ParamExtractor.string("file_name", from: arguments) ?? "<stdin>"

        do {
            let sourceFile = Parser.parse(source: code)
            let analyzer = try ComplexityAnalyzer()
            let result = try await analyzer.analyze(sourceFile: sourceFile, filePath: fileName)

            let formatter = OutputFormatter()
            let outputOptions = OutputOptions(
                showCyclomaticOnly: false,
                showCognitiveOnly: false,
                showLCOM4: false,
                threshold: nil
            )
            let output = formatter.format(results: [result], format: .json, options: outputOptions)

            return .init(
                content: [.text(text: output, annotations: nil, _meta: nil)], isError: false)

        } catch {
            return .init(
                content: [
                    .text(
                        text: "Error: \(error.localizedDescription)", annotations: nil, _meta: nil)
                ], isError: true)
        }
    }
}
