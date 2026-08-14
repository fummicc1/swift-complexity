import Foundation
import SwiftParser
import SwiftSyntax
import Testing

@testable import SwiftComplexityCore

@Suite("Type range collection", .tags(.unit, .detectors))
struct TypeRangeCollectorTests {

    private func loadCouplingFixture(_ filename: String) throws -> String {
        let url = try #require(
            Bundle.module.url(
                forResource: filename, withExtension: "swift", subdirectory: "Fixtures"))
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func collect(_ source: String) -> TypeRangeIndex {
        TypeRangeCollector.collect(
            from: Parser.parse(source: source), filePath: "test.swift")
    }

    private func entry(_ index: TypeRangeIndex, _ name: String) -> TypeRangeEntry? {
        index.entries.first { $0.name == name }
    }

    // MARK: - Collection (fixture: coupling_basic.swift)

    @Test("Collects all five nominal kinds plus extensions")
    func collectsAllDeclarationKinds() throws {
        let index = collect(try loadCouplingFixture("coupling_basic"))

        #expect(index.entries.count == 6)
        #expect(entry(index, "ServiceProtocol")?.declKind == .nominal(.protocol))
        #expect(entry(index, "Outer")?.declKind == .nominal(.struct))
        #expect(entry(index, "MyActor")?.declKind == .nominal(.actor))
        #expect(entry(index, "Payload")?.declKind == .nominal(.enum))
        // The typealias must not appear: coupling excludes typealiases.
        #expect(index.entries.allSatisfy { !$0.name.contains("Alias") })
    }

    @Test("Nested types get dotted names")
    func nestedTypeNames() throws {
        let index = collect(try loadCouplingFixture("coupling_basic"))
        #expect(entry(index, "Outer.Inner")?.declKind == .nominal(.struct))
    }

    @Test("Extensions resolve to the extended type name")
    func extensionResolution() throws {
        let index = collect(try loadCouplingFixture("coupling_basic"))
        let ext = index.entries.first {
            if case .ext = $0.declKind { return true }
            return false
        }
        #expect(ext?.declKind == .ext(extendedTypeName: "Outer"))
        #expect(ext?.resolvedTypeName == "Outer")
    }

    // MARK: - Suppression (fixture: coupling_suppressed.swift)

    @Test("Type-level suppression is collected per declaration kind")
    func suppressionPerKind() throws {
        let index = collect(try loadCouplingFixture("coupling_suppressed"))

        #expect(entry(index, "CouplingSuppressedClass")?.suppressedMetrics == [.coupling])
        // Bare disable on enum/protocol yields coupling only: lcom4 is not
        // applicable and must not leak into their sets.
        #expect(entry(index, "BareSuppressedEnum")?.suppressedMetrics == [.coupling])
        #expect(entry(index, "BareSuppressedProtocol")?.suppressedMetrics == [.coupling])
        // Bare disable on a class/struct/actor covers all type-level metrics.
        #expect(
            entry(index, "BareSuppressedStruct")?.suppressedMetrics == [.lcom4, .coupling])
    }

    @Test("Unknown metric name fails closed")
    func typoFailsClosed() throws {
        let index = collect(try loadCouplingFixture("coupling_suppressed"))
        #expect(entry(index, "TypoedClass")?.suppressedMetrics == [])
    }

    @Test("Suppression on an extension is ignored by design")
    func extensionSuppressionIgnored() throws {
        let index = collect(try loadCouplingFixture("coupling_suppressed"))
        let ext = index.entries.first {
            if case .ext = $0.declKind { return true }
            return false
        }
        #expect(ext != nil)
        #expect(ext?.suppressedMetrics == [])
    }

    // MARK: - Location lookup (inline sources: line numbers under test control)

    @Test("innermostType resolves nesting to the innermost declaration")
    func innermostNested() {
        let source = """
            struct Outer {
                struct Inner {
                    let value: Int
                }
                let outerValue: Int
            }
            """
        let index = collect(source)
        // Line 3 is inside Inner; line 5 is inside Outer only.
        #expect(index.innermostType(line: 3, column: 9)?.name == "Outer.Inner")
        #expect(index.innermostType(line: 5, column: 5)?.name == "Outer")
    }

    @Test("innermostType inside an extension resolves to the extended type")
    func innermostInExtension() {
        let source = """
            struct Target {}
            extension Target {
                func helper() {}
            }
            """
        let index = collect(source)
        #expect(index.innermostType(line: 3, column: 10)?.resolvedTypeName == "Target")
    }

    @Test("Top-level positions and type-free files resolve to nil")
    func topLevelIsNil() {
        let source = """
            import Foundation

            func freeFunction() -> Int { 1 }

            struct Later {}
            """
        let index = collect(source)
        #expect(index.innermostType(line: 3, column: 6) == nil)

        let empty = collect("func onlyFunctions() {}\n")
        #expect(empty.entries.isEmpty)
        #expect(empty.innermostType(line: 1, column: 1) == nil)
    }

    @Test("Range boundaries: declaration start is contained, past the end is not")
    func rangeBoundaries() {
        let source = """
            struct Solo {
                let x: Int
            }
            func after() {}
            """
        let index = collect(source)
        // Column 1 of line 1 is the `struct` keyword itself.
        #expect(index.innermostType(line: 1, column: 1)?.name == "Solo")
        // The closing brace line, at its column, still belongs to the type.
        #expect(index.innermostType(line: 3, column: 1)?.name == "Solo")
        // The function after the type is outside.
        #expect(index.innermostType(line: 4, column: 6) == nil)
    }

    @Test("Two declarations on one line are separated by column")
    func sameLineDeclarations() {
        let source = "struct A {}; struct B {}\n"
        let index = collect(source)
        #expect(index.innermostType(line: 1, column: 9)?.name == "A")
        #expect(index.innermostType(line: 1, column: 22)?.name == "B")
    }
}
