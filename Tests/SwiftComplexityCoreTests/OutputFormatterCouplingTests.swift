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
            results: [result(functions: [function("f", in: nil, cyclomatic: 1, cognitive: 1)], couplings: [])],
            format: .text, options: OutputOptions())
        #expect(!text.contains("Type Coupling:"))
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
