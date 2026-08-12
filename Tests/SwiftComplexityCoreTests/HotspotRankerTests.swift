import Foundation
import Testing

@testable import SwiftComplexityCore

@Suite("Hotspot ranking", .tags(.unit, .calculators))
struct HotspotRankerTests {

    // MARK: - Builders

    private func function(
        _ name: String, in typeName: String? = nil,
        cyclomatic: Int = 1, cognitive: Int = 1,
        suppressed: Set<SuppressedMetric>? = nil
    ) -> FunctionComplexity {
        FunctionComplexity(
            name: name, signature: "func \(name)()",
            cyclomaticComplexity: cyclomatic, cognitiveComplexity: cognitive,
            location: SourceLocation(line: 1, column: 1),
            enclosingTypeName: typeName,
            suppressedMetrics: suppressed)
    }

    private func coupling(_ name: String, fanIn: Int) -> TypeCoupling {
        TypeCoupling(
            name: name, kind: .class, fanIn: fanIn, fanOut: 0,
            location: SourceLocation(line: 1, column: 1))
    }

    private func result(
        _ file: String, functions: [FunctionComplexity], couplings: [TypeCoupling] = []
    ) -> ComplexityResult {
        ComplexityResult(
            filePath: file, functions: functions,
            typeCouplings: couplings.isEmpty ? nil : couplings)
    }

    private let plainThreshold = ThresholdConfiguration.empty

    // MARK: - Ordering (D3)

    @Test("Violations sort by type fan-in first, then cognitive complexity")
    func lexicographicOrder() {
        let results = [
            result(
                "A.swift",
                functions: [
                    function("lowFanInHighCognitive", in: "Quiet", cyclomatic: 12, cognitive: 30),
                    function("highFanInLowCognitive", in: "Hub", cyclomatic: 12, cognitive: 11),
                    function("highFanInHighCognitive", in: "Hub", cyclomatic: 12, cognitive: 25),
                ],
                couplings: [coupling("Hub", fanIn: 9), coupling("Quiet", fanIn: 1)])
        ]
        let hotspots = HotspotRanker.rank(
            results: results, configuration: plainThreshold, fallbackThreshold: 10)

        #expect(hotspots.map(\.function.name) == [
            "highFanInHighCognitive", "highFanInLowCognitive", "lowFanInHighCognitive",
        ])
        #expect(hotspots[0].typeFanIn == 9)
    }

    @Test("Only functions at or above the threshold appear")
    func thresholdFilter() {
        let results = [
            result(
                "A.swift",
                functions: [
                    function("atThreshold", in: "T", cyclomatic: 10, cognitive: 1),
                    function("belowThreshold", in: "T", cyclomatic: 9, cognitive: 1),
                ],
                couplings: [coupling("T", fanIn: 3)])
        ]
        let hotspots = HotspotRanker.rank(
            results: results, configuration: plainThreshold, fallbackThreshold: 10)
        #expect(hotspots.map(\.function.name) == ["atThreshold"])
    }

    @Test("The limit caps the ranking")
    func limitApplies() {
        let functions = (0..<12).map {
            function("f\($0)", in: "T", cyclomatic: 11, cognitive: 20 - $0)
        }
        let results = [result("A.swift", functions: functions)]
        let hotspots = HotspotRanker.rank(
            results: results, configuration: plainThreshold, fallbackThreshold: 10, limit: 10)
        #expect(hotspots.count == 10)
        // The two lowest-cognitive entries fall off.
        #expect(!hotspots.contains { $0.function.name == "f11" })
    }

    @Test("Per-type threshold rules decide the violation set")
    func perTypeRules() {
        let config = ThresholdConfiguration(
            rules: [ThresholdRule(suffix: "ViewModel", threshold: 5)])
        let results = [
            result(
                "A.swift",
                functions: [
                    function("strictlyJudged", in: "HomeViewModel", cyclomatic: 6, cognitive: 1),
                    function("leniently", in: "HomeService", cyclomatic: 6, cognitive: 1),
                ])
        ]
        // fallback 10: the ViewModel rule (5) flags the first function only.
        let hotspots = HotspotRanker.rank(
            results: results, configuration: config, fallbackThreshold: 10)
        #expect(hotspots.map(\.function.name) == ["strictlyJudged"])
    }

    @Test("Suppressed functions never rank")
    func suppressionExcludes() {
        let results = [
            result(
                "A.swift",
                functions: [
                    function(
                        "suppressed", in: "T", cyclomatic: 30, cognitive: 30,
                        suppressed: [.cyclomatic, .cognitive])
                ])
        ]
        let hotspots = HotspotRanker.rank(
            results: results, configuration: plainThreshold, fallbackThreshold: 10)
        #expect(hotspots.isEmpty)
    }

    // MARK: - Degenerate cases

    @Test("No threshold anywhere means no hotspots")
    func noThresholdNoHotspots() {
        let results = [
            result("A.swift", functions: [function("f", in: "T", cyclomatic: 99, cognitive: 99)])
        ]
        let hotspots = HotspotRanker.rank(
            results: results, configuration: .empty, fallbackThreshold: nil)
        #expect(hotspots.isEmpty)
    }

    @Test("Free functions rank with fan-in 0 and sink to the bottom")
    func freeFunctionsSink() {
        let results = [
            result(
                "A.swift",
                functions: [
                    function("free", in: nil, cyclomatic: 11, cognitive: 40),
                    function("member", in: "T", cyclomatic: 11, cognitive: 12),
                ],
                couplings: [coupling("T", fanIn: 2)])
        ]
        let hotspots = HotspotRanker.rank(
            results: results, configuration: plainThreshold, fallbackThreshold: 10)
        #expect(hotspots.map(\.function.name) == ["member", "free"])
        #expect(hotspots[1].typeFanIn == 0)
    }

    @Test("Ambiguous type names without a same-file match resolve to fan-in 0")
    func ambiguousTypeName() {
        let results = [
            result(
                "A.swift",
                functions: [function("f", in: "Widget", cyclomatic: 11, cognitive: 11)]),
            result("B.swift", functions: [], couplings: [coupling("Widget", fanIn: 5)]),
            result("C.swift", functions: [], couplings: [coupling("Widget", fanIn: 8)]),
        ]
        let hotspots = HotspotRanker.rank(
            results: results, configuration: plainThreshold, fallbackThreshold: 10)
        #expect(hotspots[0].typeFanIn == 0)
    }

    @Test("Nested type coupling names match simple enclosing names by suffix")
    func nestedNameSuffixMatch() {
        let results = [
            result(
                "A.swift",
                functions: [function("f", in: "Inner", cyclomatic: 11, cognitive: 11)],
                couplings: [coupling("Outer.Inner", fanIn: 4)])
        ]
        let hotspots = HotspotRanker.rank(
            results: results, configuration: plainThreshold, fallbackThreshold: 10)
        #expect(hotspots[0].typeFanIn == 4)
    }

    @Test("Violations without any coupling data still rank (fan-in 0)")
    func noCouplingDataStillRanks() {
        let results = [
            result("A.swift", functions: [function("f", in: "T", cyclomatic: 11, cognitive: 11)])
        ]
        let hotspots = HotspotRanker.rank(
            results: results, configuration: plainThreshold, fallbackThreshold: 10)
        #expect(hotspots.count == 1)
        #expect(hotspots[0].typeFanIn == 0)
    }
}
