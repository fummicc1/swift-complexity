import Foundation
import SwiftParser
import SwiftSyntax
import Testing

@testable import SwiftComplexityCore

/// Analyzes `source` and returns the reported functions keyed by name.
private func analyze(_ source: String) async throws -> [String: FunctionComplexity] {
    let analyzer = try ComplexityAnalyzer()
    let result = try await analyzer.analyze(
        sourceFile: Parser.parse(source: source), filePath: "test.swift")
    return Dictionary(
        result.functions.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
}

@Suite("End locations", .tags(.unit, .detectors))
struct EndLocationTests {

    @Test("Every kind of function-level declaration reports where it ends")
    func endLocationPerDeclarationKind() async throws {
        let functions = try await analyze(
            """
            final class Box {
                var value = 0
                init() {
                    value = 1
                }
                deinit {
                    print(value)
                }
                func method() {
                    print(value)
                }
                var shorthand: Int {
                    value * 2
                }
                var explicit: Int {
                    get { value }
                    set { value = newValue }
                }
            }
            """)

        // Columns are 1-based and point just past the closing brace.
        #expect(functions["init"]?.endLocation == SourceLocation(line: 5, column: 6))
        #expect(functions["deinit"]?.endLocation == SourceLocation(line: 8, column: 6))
        #expect(functions["method"]?.endLocation == SourceLocation(line: 11, column: 6))
        #expect(functions["shorthand"]?.endLocation == SourceLocation(line: 14, column: 6))
        #expect(functions["explicit.get"]?.endLocation == SourceLocation(line: 16, column: 22))
        #expect(functions["explicit.set"]?.endLocation == SourceLocation(line: 17, column: 33))
    }

    @Test("A function's end is after its start, spanning its body")
    func endFollowsStart() async throws {
        let functions = try await analyze(
            """
            func f(_ a: Bool) -> Int {
                if a {
                    return 1
                }
                return 0
            }
            """)

        let f = try #require(functions["f"])
        #expect(f.location == SourceLocation(line: 1, column: 1))
        #expect(f.endLocation == SourceLocation(line: 6, column: 2))
    }

    @Test("endLocation is encoded in JSON and omitted when absent")
    func jsonEncoding() throws {
        let withEnd = FunctionComplexity(
            name: "f", signature: "func f()", cyclomaticComplexity: 1, cognitiveComplexity: 0,
            location: SourceLocation(line: 1, column: 1),
            endLocation: SourceLocation(line: 3, column: 2))
        let withoutEnd = FunctionComplexity(
            name: "f", signature: "func f()", cyclomaticComplexity: 1, cognitiveComplexity: 0,
            location: SourceLocation(line: 1, column: 1))

        let withEndJSON = String(decoding: try JSONEncoder().encode(withEnd), as: UTF8.self)
        let withoutEndJSON = String(decoding: try JSONEncoder().encode(withoutEnd), as: UTF8.self)

        #expect(withEndJSON.contains("\"endLocation\""))
        #expect(!withoutEndJSON.contains("endLocation"))
    }

    @Test("Results encoded before endLocation existed still decode")
    func legacyJSONDecodes() throws {
        let legacy = """
            {"name":"f","signature":"func f()","cyclomaticComplexity":2,
             "cognitiveComplexity":1,"location":{"line":4,"column":5}}
            """

        let decoded = try JSONDecoder().decode(FunctionComplexity.self, from: Data(legacy.utf8))

        #expect(decoded.location == SourceLocation(line: 4, column: 5))
        #expect(decoded.endLocation == nil)
    }

    @Test("XML output carries end-line and end-column only when known")
    func xmlAttributes() {
        let options = OutputOptions()
        let withEnd = ComplexityResult(
            filePath: "A.swift",
            functions: [
                FunctionComplexity(
                    name: "f", signature: "func f()", cyclomaticComplexity: 1,
                    cognitiveComplexity: 0, location: SourceLocation(line: 1, column: 1),
                    endLocation: SourceLocation(line: 3, column: 2))
            ])
        let withoutEnd = ComplexityResult(
            filePath: "A.swift",
            functions: [
                FunctionComplexity(
                    name: "f", signature: "func f()", cyclomaticComplexity: 1,
                    cognitiveComplexity: 0, location: SourceLocation(line: 1, column: 1))
            ])

        let withEndXML = OutputFormatter().format(
            results: [withEnd], format: .xml, options: options)
        let withoutEndXML = OutputFormatter().format(
            results: [withoutEnd], format: .xml, options: options)

        #expect(withEndXML.contains("line=\"1\" column=\"1\" end-line=\"3\" end-column=\"2\">"))
        #expect(withoutEndXML.contains("line=\"1\" column=\"1\">"))
        #expect(!withoutEndXML.contains("end-line"))
    }
}

@Suite("Subscript detection", .tags(.unit, .detectors))
struct SubscriptDetectionTests {

    @Test("Shorthand subscript getter is reported with its complexity")
    func shorthandSubscript() async throws {
        let functions = try await analyze(
            """
            struct Grid {
                var cells: [Int] = []
                subscript(i: Int) -> Int {
                    if i < 0 { return 0 }
                    return cells[i]
                }
            }
            """)

        let subscriptFunction = try #require(functions["subscript"])
        #expect(subscriptFunction.signature == "subscript(i: Int) -> Int")
        #expect(subscriptFunction.enclosingTypeName == "Grid")
        #expect(subscriptFunction.location == SourceLocation(line: 3, column: 5))
        #expect(subscriptFunction.endLocation == SourceLocation(line: 6, column: 6))
        // base(1) + if(1)
        #expect(subscriptFunction.cyclomaticComplexity == 2)
        #expect(subscriptFunction.cognitiveComplexity == 1)
    }

    @Test("Explicit subscript accessors are named after the subscript")
    func explicitSubscriptAccessors() async throws {
        let functions = try await analyze(
            """
            struct Store {
                var values: [String: Int] = [:]
                subscript<Key: CustomStringConvertible>(key: Key) -> Int {
                    get {
                        if let value = values[key.description] { return value }
                        return 0
                    }
                    set { values[key.description] = newValue }
                }
            }
            """)

        let getter = try #require(functions["subscript.get"])
        let setter = try #require(functions["subscript.set"])
        #expect(
            getter.signature == "subscript<Key: CustomStringConvertible>(key: Key) -> Int { get }")
        #expect(
            setter.signature == "subscript<Key: CustomStringConvertible>(key: Key) -> Int { set }")
        #expect(getter.cyclomaticComplexity == 2)
        #expect(setter.cyclomaticComplexity == 1)
        #expect(functions["subscript"] == nil)
    }

    @Test("Subscript requirements in a protocol are not reported")
    func protocolSubscript() async throws {
        let functions = try await analyze(
            """
            protocol Indexable {
                subscript(i: Int) -> Int { get }
            }
            """)

        #expect(functions.isEmpty)
    }

    @Test("A suppression comment above a subscript applies to it")
    func subscriptSuppression() async throws {
        let functions = try await analyze(
            """
            struct Grid {
                // swift-complexity:disable cyclomatic
                subscript(i: Int) -> Int { i }
            }
            """)

        #expect(functions["subscript"]?.suppressedMetrics == [.cyclomatic])
    }
}
