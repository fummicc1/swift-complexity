import Foundation
import Testing

@testable import SwiftComplexityCore

@Suite("Coupling text output", .tags(.unit, .formatters))
struct OutputFormatterCouplingTests {

    private func result(
        functions: [FunctionComplexity] = [],
        couplings: [TypeCoupling]? = nil
    ) -> ComplexityResult {
        ComplexityResult(filePath: "A.swift", functions: functions, typeCouplings: couplings)
    }

    private func function(
        _ name: String, in typeName: String?, cyclomatic: Int, cognitive: Int
    ) -> FunctionComplexity {
        FunctionComplexity(
            name: name, signature: "func \(name)()",
            cyclomaticComplexity: cyclomatic, cognitiveComplexity: cognitive,
            location: SourceLocation(line: 1, column: 1),
            enclosingTypeName: typeName)
    }

    @Test("Type coupling table renders values and dashes for undefined instability")
    func couplingTableRendering() {
        let couplings = [
            TypeCoupling(
                name: "Hub", kind: .class, fanIn: 3, fanOut: 24,
                location: SourceLocation(line: 1, column: 1)),
            TypeCoupling(
                name: "Isolated", kind: .enum, fanIn: 0, fanOut: 0,
                location: SourceLocation(line: 9, column: 1)),
        ]
        let text = OutputFormatter().format(
            results: [result(couplings: couplings)], format: .text, options: OutputOptions())

        #expect(text.contains("Type Coupling:"))
        #expect(text.contains("| Fan-In | Fan-Out | Instability |"))
        #expect(text.contains("0.89"))  // 24 / 27
        #expect(text.contains("Isolated"))
        // Undefined instability renders as a dash, never 0.00.
        let isolatedRow = text.split(separator: "\n").first { $0.contains("Isolated") }
        #expect(isolatedRow?.contains("-") == true)
        #expect(text.contains("Total: 2 types"))
    }

    @Test("Empty coupling arrays render no table (coupling ran, no types)")
    func emptyCouplingsNoTable() {
        let text = OutputFormatter().format(
            results: [
                result(
                    functions: [function("f", in: nil, cyclomatic: 1, cognitive: 1)], couplings: [])
            ],
            format: .text, options: OutputOptions())
        #expect(!text.contains("Type Coupling:"))
    }

    // MARK: - SARIF

    private func sarifResults(
        couplings: [TypeCoupling], configuration: ThresholdConfiguration?
    ) throws -> [[String: Any]] {
        let output = OutputFormatter().format(
            results: [result(couplings: couplings)], format: .sarif,
            options: OutputOptions(thresholdConfiguration: configuration))
        let json = try #require(
            try JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any])
        let runs = try #require(json["runs"] as? [[String: Any]])
        return try #require(runs[0]["results"] as? [[String: Any]])
    }

    @Test("Fan-out violations become type_fan_out results, error at double the threshold")
    func sarifFanOutLevels() throws {
        let configuration = ThresholdConfiguration(coupling: CouplingThresholds(fanOut: 10))
        let couplings = [
            TypeCoupling(
                name: "Warning", kind: .struct, fanIn: 0, fanOut: 10,
                location: SourceLocation(line: 1, column: 1)),
            TypeCoupling(
                name: "Error", kind: .class, fanIn: 0, fanOut: 20,
                location: SourceLocation(line: 9, column: 1)),
        ]
        let results = try sarifResults(couplings: couplings, configuration: configuration)

        #expect(results.count == 2)
        let warning = try #require(results.first { $0["level"] as? String == "warning" })
        #expect(warning["ruleId"] as? String == "type_fan_out")
        let message = try #require((warning["message"] as? [String: Any])?["text"] as? String)
        #expect(message.contains("'Warning' has fan-out 10 (threshold: 10)"))
        let error = try #require(results.first { $0["level"] as? String == "error" })
        #expect((error["message"] as? [String: Any])?["text"] as? String != nil)
    }

    @Test("Fan-in thresholds are judged by their own rule")
    func sarifFanInRule() throws {
        let configuration = ThresholdConfiguration(coupling: CouplingThresholds(fanIn: 5))
        let couplings = [
            TypeCoupling(
                name: "Hub", kind: .protocol, fanIn: 6, fanOut: 0,
                location: SourceLocation(line: 1, column: 1))
        ]
        let results = try sarifResults(couplings: couplings, configuration: configuration)
        #expect(results.count == 1)
        #expect(results[0]["ruleId"] as? String == "type_fan_in")
    }

    @Test("Without coupling thresholds the SARIF report carries no coupling results")
    func sarifReportOnlyWithoutConfig() throws {
        let couplings = [
            TypeCoupling(
                name: "Huge", kind: .class, fanIn: 99, fanOut: 99,
                location: SourceLocation(line: 1, column: 1))
        ]
        // A configuration without a coupling block, and no configuration at all.
        for configuration in [ThresholdConfiguration(defaultThreshold: 10), nil] {
            let results = try sarifResults(couplings: couplings, configuration: configuration)
            #expect(results.isEmpty)
        }
    }

    @Test("Suppressed types produce no SARIF coupling results")
    func sarifSuppressionSkips() throws {
        let configuration = ThresholdConfiguration(coupling: CouplingThresholds(fanOut: 1))
        let couplings = [
            TypeCoupling(
                name: "Muted", kind: .class, fanIn: 0, fanOut: 30,
                location: SourceLocation(line: 1, column: 1),
                suppressedMetrics: [.coupling])
        ]
        let results = try sarifResults(couplings: couplings, configuration: configuration)
        #expect(results.isEmpty)
    }

    @Test("Hotspots appear only with a threshold, coupling data, and violations")
    func hotspotVisibilityConditions() {
        let violating = function("busy", in: "Hub", cyclomatic: 12, cognitive: 15)
        let hub = TypeCoupling(
            name: "Hub", kind: .class, fanIn: 7, fanOut: 1,
            location: SourceLocation(line: 1, column: 1))
        let formatter = OutputFormatter()

        // Threshold + coupling + violation: section renders with the rank row.
        let shown = formatter.format(
            results: [result(functions: [violating], couplings: [hub])],
            format: .text, options: OutputOptions(threshold: 10))
        #expect(shown.contains("Hotspots"))
        #expect(shown.contains("busy"))
        #expect(shown.contains("| 1 "))

        // No threshold: violations are undefined, so no section.
        let noThreshold = formatter.format(
            results: [result(functions: [violating], couplings: [hub])],
            format: .text, options: OutputOptions())
        #expect(!noThreshold.contains("Hotspots"))

        // Threshold but coupling never ran: no section.
        let noCoupling = formatter.format(
            results: [result(functions: [violating])],
            format: .text, options: OutputOptions(threshold: 10))
        #expect(!noCoupling.contains("Hotspots"))

        // Threshold + coupling but nothing violates: no section.
        let calm = formatter.format(
            results: [
                result(
                    functions: [function("calm", in: "Hub", cyclomatic: 2, cognitive: 2)],
                    couplings: [hub])
            ],
            format: .text, options: OutputOptions(threshold: 10))
        #expect(!calm.contains("Hotspots"))
    }
}
