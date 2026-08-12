import Foundation
import Testing

@testable import SwiftComplexityCore

// macOS-only on purpose: the goldens are generated on macOS, and this gate
// measures regressions introduced by code changes, not platform variance in
// Foundation's JSON encoding/parsing (which made the comparison fail on
// Linux). Linux output is exercised by the CI integration steps instead,
// and Linux LCOM4 would additionally need a resolved --toolchain-path.
#if os(macOS)

    /// Regression gate for the coupling-metrics feature: analysis WITHOUT
    /// `--coupling` must keep producing exactly the output of the release the
    /// goldens were generated from (see `Fixtures/golden/README.md`).
    @Suite("Golden output compatibility", .tags(.integration))
    struct GoldenCompatibilityTests {

        /// The fixture files frozen into the goldens. Pinned by name so that
        /// fixtures added for later features cannot silently change this test's
        /// input; regenerating the goldens is the only way to extend the list.
        private static let goldenFixtureNames = [
            "class_with_methods", "cognitive_nested_conditions", "computed_property",
            "else_if_chain", "function_with_if", "integration_test_sample",
            "issue6_nested_else_if", "nested_conditions", "protocol_decl",
            "protocol_extension_decl", "simple_function", "single_function",
            "suppressed_functions", "suppressed_types", "very_complex_function",
        ]

        /// Repository root, derived from this source file's location so the test
        /// analyzes the repo-checkout fixtures with paths matching the goldens.
        private var repoRoot: URL {
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()  // SwiftComplexityCoreTests
                .deletingLastPathComponent()  // Tests
                .deletingLastPathComponent()  // repo root
        }

        private var fixturesDirectory: URL {
            repoRoot
                .appendingPathComponent("Tests")
                .appendingPathComponent("SwiftComplexityCoreTests")
                .appendingPathComponent("Fixtures")
        }

        private func fixturePaths() -> [String] {
            Self.goldenFixtureNames.map {
                fixturesDirectory.appendingPathComponent("\($0).swift").path
            }
        }

        /// Canonical form shared with the goldens: repo-relative paths, then a
        /// JSON object tree whose `suppressedMetrics` arrays are sorted (Set
        /// encoding order is nondeterministic). Object key order is irrelevant to
        /// the NSDictionary comparison used by the tests.
        private func canonicalize(_ json: String) throws -> NSDictionary {
            let relativized = json.replacingOccurrences(of: repoRoot.path + "/", with: "")
            let object = try JSONSerialization.jsonObject(with: Data(relativized.utf8))
            let dictionary = try #require(object as? [String: Any])
            return try #require(normalized(dictionary) as? NSDictionary)
        }

        private func normalized(_ value: Any) -> Any {
            if let dictionary = value as? [String: Any] {
                var result: [String: Any] = [:]
                for (key, element) in dictionary {
                    if key == "suppressedMetrics", let metrics = element as? [String] {
                        result[key] = metrics.sorted()
                    } else {
                        result[key] = normalized(element)
                    }
                }
                return result
            }
            if let array = value as? [Any] {
                return array.map(normalized)
            }
            return value
        }

        private func loadGolden(_ name: String) throws -> NSDictionary {
            let url = try #require(
                Bundle.module.url(
                    forResource: name, withExtension: "json", subdirectory: "Fixtures/golden"),
                "golden fixture \(name).json must be bundled")
            let json = try String(contentsOf: url, encoding: .utf8)
            let object = try JSONSerialization.jsonObject(with: Data(json.utf8))
            let dictionary = try #require(object as? [String: Any])
            return try #require(normalized(dictionary) as? NSDictionary)
        }

        @Test("Plain JSON output matches the pre-coupling golden")
        func plainOutputMatchesGolden() async throws {
            let analyzer = try ComplexityAnalyzer()
            let processor = FileProcessor(analyzer: analyzer)
            let results = try await processor.processFiles(
                at: fixturePaths(), options: ProcessingOptions())

            let output = OutputFormatter().format(
                results: results, format: .json, options: OutputOptions())

            #expect(try canonicalize(output) == loadGolden("complexity_plain"))
        }

        @Test("LCOM4 JSON output matches the pre-coupling golden")
        func lcom4OutputMatchesGolden() async throws {
            // The store only needs to exist: fixture types are not indexed, so
            // LCOM4 resolves through the deterministic syntax fallback — exactly
            // how the golden was generated. `swift test` always builds first, so
            // the debug index store is present in every supported flow.
            let indexStore =
                repoRoot
                .appendingPathComponent(".build")
                .appendingPathComponent("debug")
                .appendingPathComponent("index")
                .appendingPathComponent("store")
            try #require(
                FileManager.default.fileExists(atPath: indexStore.path),
                "debug index store missing — run via `swift test` (not a bare Xcode test action)")

            let analyzer = try ComplexityAnalyzer(indexStorePath: indexStore)
            let processor = FileProcessor(analyzer: analyzer)
            let results = try await processor.processFiles(
                at: fixturePaths(), options: ProcessingOptions())

            let output = OutputFormatter().format(
                results: results, format: .json, options: OutputOptions(showLCOM4: true))

            #expect(try canonicalize(output) == loadGolden("complexity_lcom4"))
        }
    }

#endif

/// Behavior of the coupling fields themselves (additive schema).
@Suite("ComplexityResult coupling fields", .tags(.unit, .models))
struct ComplexityResultCouplingTests {

    private func sampleResult() -> ComplexityResult {
        ComplexityResult(
            filePath: "A.swift",
            functions: [
                FunctionComplexity(
                    name: "f", signature: "func f()",
                    cyclomaticComplexity: 2, cognitiveComplexity: 3,
                    location: SourceLocation(line: 1, column: 1))
            ])
    }

    @Test("attaching(typeCouplings:) preserves inputs and recomputes summaries deterministically")
    func attachingIsDeterministic() throws {
        let base = sampleResult()
        let coupling = TypeCoupling(
            name: "A", kind: .struct, fanIn: 2, fanOut: 1,
            location: SourceLocation(line: 1, column: 1))

        let attached = base.attaching(typeCouplings: [coupling])

        #expect(attached.filePath == base.filePath)
        #expect(attached.functions == base.functions)
        #expect(attached.classCohesions == base.classCohesions)
        // Summary is rebuilt from the same functions, so it must be identical.
        #expect(attached.summary.totalFunctions == base.summary.totalFunctions)
        #expect(
            attached.summary.averageCyclomaticComplexity
                == base.summary.averageCyclomaticComplexity)
        #expect(attached.typeCouplings == [coupling])
        #expect(attached.couplingSummary?.totalTypes == 1)
    }

    @Test("Coupling keys are absent from JSON until coupling analysis runs")
    func couplingKeysAbsentByDefault() throws {
        let json = String(
            decoding: try JSONEncoder().encode(sampleResult()), as: UTF8.self)
        #expect(!json.contains("typeCouplings"))
        #expect(!json.contains("couplingSummary"))

        let attached = sampleResult().attaching(typeCouplings: [])
        let attachedJSON = String(
            decoding: try JSONEncoder().encode(attached), as: UTF8.self)
        #expect(attachedJSON.contains("typeCouplings"))
        #expect(attachedJSON.contains("couplingSummary"))
    }
}
