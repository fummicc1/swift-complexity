import Foundation
import IndexStoreDB
import Testing

@testable import SwiftComplexityCore

/// Unit tests for the pure attribution algorithm. Records are hand-written
/// stand-ins for IndexStoreDB occurrences; their relation shapes mirror what
/// the coupling spike observed against a real index store.
@Suite("Reference graph builder", .tags(.unit, .calculators))
struct ReferenceGraphBuilderTests {

    // MARK: - Record helpers

    private func def(
        _ usr: String, _ name: String, _ kind: IndexSymbolKind,
        file: String = "A.swift", at position: (line: Int, column: Int) = (1, 1),
        childOf parent: String? = nil
    ) -> IndexOccurrenceRecord {
        IndexOccurrenceRecord(
            usr: usr, name: name, kind: kind,
            file: file, line: position.line, column: position.column,
            roles: .definition,
            relations: parent.map {
                [RecordRelation(usr: $0, kind: .struct, roles: .childOf)]
            } ?? [])
    }

    private func ref(
        _ usr: String, kind: IndexSymbolKind = .struct,
        file: String = "A.swift", at position: (line: Int, column: Int) = (50, 1),
        containedBy container: String? = nil,
        extendedBy extensionUSR: String? = nil,
        baseOf conformer: String? = nil
    ) -> IndexOccurrenceRecord {
        var relations: [RecordRelation] = []
        if let container {
            relations.append(
                RecordRelation(usr: container, kind: .instanceMethod, roles: .containedBy))
        }
        if let extensionUSR {
            relations.append(
                RecordRelation(usr: extensionUSR, kind: .extension, roles: .extendedBy))
        }
        if let conformer {
            relations.append(
                RecordRelation(usr: conformer, kind: .struct, roles: .baseOf))
        }
        return IndexOccurrenceRecord(
            usr: usr, name: usr, kind: kind,
            file: file, line: position.line, column: position.column,
            roles: .reference, relations: relations)
    }

    /// A range index whose single entry spans the given lines of `file`.
    private func rangeIndex(
        _ name: String, kind: NominalType = .enum,
        lines: ClosedRange<Int>
    ) -> TypeRangeIndex {
        TypeRangeIndex(entries: [
            TypeRangeEntry(
                name: name, declKind: .nominal(kind),
                startLine: lines.lowerBound, startColumn: 1,
                endLine: lines.upperBound, endColumn: 80,
                suppressedMetrics: [])
        ])
    }

    private func build(
        _ occurrences: [IndexOccurrenceRecord],
        typeRanges: [String: TypeRangeIndex] = [:]
    ) -> (graph: ReferenceGraph, diagnostics: CouplingDiagnostics) {
        ReferenceGraphBuilder.build(occurrences: occurrences, typeRanges: typeRanges)
    }

    /// The standard two-type scenario: A.method references B.
    private var basicScenario: [IndexOccurrenceRecord] {
        [
            def("s:A", "A", .struct),
            def("s:A.m", "m()", .instanceMethod, childOf: "s:A"),
            def("s:B", "B", .struct, at: (10, 1)),
            ref("s:B", containedBy: "s:A.m"),
        ]
    }

    // MARK: - Core attribution

    @Test("Reference inside a method becomes an edge from the owning type")
    func containedByAttribution() {
        let (graph, diagnostics) = build(basicScenario)
        #expect(graph.outEdges["s:A"] == ["s:B"])
        #expect(graph.inEdges["s:B"] == ["s:A"])
        #expect(diagnostics.attributedByContainedBy == 1)
    }

    @Test("Multi-hop childOf chains resolve to the innermost owning type")
    func childOfChainResolution() {
        // A reference contained by an accessor-like symbol nested under a
        // method nested under the type.
        let records = [
            def("s:A", "A", .struct),
            def("s:A.m", "m()", .instanceMethod, childOf: "s:A"),
            def("s:A.m.acc", "get", .function, childOf: "s:A.m"),
            def("s:B", "B", .struct, at: (10, 1)),
            ref("s:B", containedBy: "s:A.m.acc"),
        ]
        let (graph, _) = build(records)
        #expect(graph.outEdges["s:A"] == ["s:B"])
    }

    @Test("Members defined in extensions attribute to the extended type")
    func extensionAttribution() {
        let records = [
            def("s:Foo", "Foo", .struct),
            def("s:e:Foo", "Foo", .extension, at: (20, 1)),
            // The `Foo` reference in `extension Foo` registers the mapping.
            ref("s:Foo", at: (20, 11), extendedBy: "s:e:Foo"),
            def("s:Foo.extra", "extra()", .instanceMethod, at: (21, 5), childOf: "s:e:Foo"),
            def("s:Bar", "Bar", .struct, at: (30, 1)),
            ref("s:Bar", at: (22, 9), containedBy: "s:Foo.extra"),
        ]
        let (graph, _) = build(records)
        #expect(graph.outEdges["s:Foo"] == ["s:Bar"])
    }

    @Test("References to a member count toward the member's owning type")
    func memberTargetResolution() {
        // A.m references B.helper -> edge A -> B, not A -> helper.
        let records = [
            def("s:A", "A", .struct),
            def("s:A.m", "m()", .instanceMethod, childOf: "s:A"),
            def("s:B", "B", .struct, at: (10, 1)),
            def("s:B.helper", "helper()", .instanceMethod, at: (11, 5), childOf: "s:B"),
            ref("s:B.helper", kind: .instanceMethod, containedBy: "s:A.m"),
        ]
        let (graph, _) = build(records)
        #expect(graph.outEdges["s:A"] == ["s:B"])
    }

    // MARK: - Aggregation

    @Test("Fan counts aggregate distinct types over a small graph")
    func fanAggregation() {
        // A -> B, A -> C, C -> B
        let records = [
            def("s:A", "A", .struct),
            def("s:A.m", "m()", .instanceMethod, childOf: "s:A"),
            def("s:B", "B", .struct, at: (10, 1)),
            def("s:C", "C", .struct, at: (20, 1)),
            def("s:C.m", "m()", .instanceMethod, at: (21, 5), childOf: "s:C"),
            ref("s:B", containedBy: "s:A.m"),
            ref("s:C", containedBy: "s:A.m"),
            ref("s:B", at: (60, 1), containedBy: "s:C.m"),
        ]
        let (graph, _) = build(records)
        #expect(graph.fanOut(of: "s:A") == 2)
        #expect(graph.fanIn(of: "s:A") == 0)
        #expect(graph.fanOut(of: "s:B") == 0)
        #expect(graph.fanIn(of: "s:B") == 2)
        #expect(graph.fanOut(of: "s:C") == 1)
        #expect(graph.fanIn(of: "s:C") == 1)
    }

    @Test("Repeated references to one type count once (distinct types)")
    func distinctCounting() {
        let records = basicScenario + [
            ref("s:B", at: (51, 1), containedBy: "s:A.m"),
            ref("s:B", at: (52, 1), containedBy: "s:A.m"),
        ]
        let (graph, _) = build(records)
        #expect(graph.fanOut(of: "s:A") == 1)
        #expect(graph.fanIn(of: "s:B") == 1)
    }

    @Test("Nested types are independent nodes; inner-outer references count")
    func nestedTypesAreIndependent() {
        let records = [
            def("s:Outer", "Outer", .struct),
            def("s:Outer.Inner", "Inner", .struct, at: (2, 5), childOf: "s:Outer"),
            def("s:Outer.Inner.m", "m()", .instanceMethod, at: (3, 9), childOf: "s:Outer.Inner"),
            ref("s:Outer", at: (3, 20), containedBy: "s:Outer.Inner.m"),
        ]
        let (graph, _) = build(records)
        #expect(graph.outEdges["s:Outer.Inner"] == ["s:Outer"])
        #expect(graph.nodes["s:Outer.Inner"] != nil)
        #expect(graph.nodes["s:Outer"] != nil)
    }

    @Test("Mutual references stay directional")
    func mutualReferences() {
        let records = [
            def("s:A", "A", .struct),
            def("s:A.m", "m()", .instanceMethod, childOf: "s:A"),
            def("s:B", "B", .struct, at: (10, 1)),
            def("s:B.m", "m()", .instanceMethod, at: (11, 5), childOf: "s:B"),
            ref("s:B", containedBy: "s:A.m"),
            ref("s:A", at: (60, 1), containedBy: "s:B.m"),
        ]
        let (graph, _) = build(records)
        #expect(graph.outEdges["s:A"] == ["s:B"])
        #expect(graph.outEdges["s:B"] == ["s:A"])
    }

    // MARK: - Node metadata

    @Test("Syntax ranges override the index kind (actor) and provide names")
    func syntaxKindWins() {
        let entry = TypeRangeEntry(
            name: "MyActor", declKind: .nominal(.actor),
            startLine: 1, startColumn: 1, endLine: 5, endColumn: 1,
            suppressedMetrics: [.coupling])
        let ranges = ["A.swift": TypeRangeIndex(entries: [entry])]
        // The index reports actors as classes.
        let records = [def("s:MyActor", "MyActor", .class, at: (1, 7))]

        let (graph, _) = build(records, typeRanges: ranges)
        #expect(graph.nodes["s:MyActor"]?.kind == .actor)
        #expect(graph.nodes["s:MyActor"]?.suppressedMetrics == [.coupling])
    }

    @Test("Types without a syntax entry fall back to index metadata")
    func fallbackToIndexMetadata() {
        let (graph, _) = build([def("s:E", "E", .enum)])
        #expect(graph.nodes["s:E"]?.kind == .enum)
        #expect(graph.nodes["s:E"]?.name == "E")
        #expect(graph.nodes["s:E"]?.suppressedMetrics == [])
    }

    // MARK: - Exclusions and robustness

    @Test("Self references produce no edge but are accounted for")
    func selfReferenceExcluded() {
        let records = [
            def("s:A", "A", .struct),
            def("s:A.m", "m()", .instanceMethod, childOf: "s:A"),
            def("s:A.other", "other()", .instanceMethod, at: (5, 5), childOf: "s:A"),
            ref("s:A.other", kind: .instanceMethod, containedBy: "s:A.m"),
        ]
        let (graph, diagnostics) = build(records)
        #expect(graph.outEdges["s:A"] == nil)
        #expect(diagnostics.selfReferencesSkipped == 1)
    }

    @Test("References to symbols outside the analyzed files are dropped")
    func nonProjectSymbolDropped() {
        let records = basicScenario + [
            // No definition record exists for String: not a project symbol.
            ref("s:Swift.String", at: (60, 1), containedBy: "s:A.m")
        ]
        let (graph, diagnostics) = build(records)
        #expect(diagnostics.droppedNonProjectSymbol == 1)
        #expect(graph.fanOut(of: "s:A") == 1)  // only the edge to B
    }

    @Test("Isolated types keep zero fan counts")
    func isolatedType() {
        let (graph, _) = build([def("s:Lonely", "Lonely", .struct)])
        #expect(graph.nodes["s:Lonely"] != nil)
        #expect(graph.fanIn(of: "s:Lonely") == 0)
        #expect(graph.fanOut(of: "s:Lonely") == 0)
    }

    @Test("Corrupt parent cycles drop the reference instead of hanging")
    func parentCycleGuard() {
        let records = [
            def("s:A", "A", .struct),
            def("s:A.m", "m()", .instanceMethod, childOf: "s:A"),
            // x and y form a childOf cycle and never reach a type.
            def("s:x", "x", .function, at: (30, 1), childOf: "s:y"),
            def("s:y", "y", .function, at: (31, 1), childOf: "s:x"),
            def("s:B", "B", .struct, at: (10, 1)),
            ref("s:B", containedBy: "s:x"),
        ]
        let (graph, diagnostics) = build(records)
        #expect(graph.outEdges.isEmpty)
        #expect(diagnostics.droppedUnattributable == 1)
    }

    @Test("Empty input builds an empty graph with zeroed diagnostics")
    func emptyInput() {
        let (graph, diagnostics) = build([])
        #expect(graph.nodes.isEmpty)
        #expect(graph.outEdges.isEmpty)
        #expect(diagnostics == CouplingDiagnostics())
    }

    // MARK: - Fallback attribution

    @Test("Conformance clauses recover edges through the baseOf relation")
    func baseOfConformanceEdge() {
        // `struct Foo: P` - the P reference has only a baseOf relation
        // pointing at the conforming type.
        let records = [
            def("s:P", "P", .protocol),
            def("s:Foo", "Foo", .struct, at: (10, 1)),
            ref("s:P", kind: .protocol, at: (10, 13), baseOf: "s:Foo"),
        ]
        let (graph, diagnostics) = build(records)
        #expect(graph.outEdges["s:Foo"] == ["s:P"])
        #expect(diagnostics.attributedByBaseOf == 1)
    }

    @Test("Protocol fan-in counts every conformer")
    func protocolFanIn() {
        let records = [
            def("s:P", "P", .protocol),
            def("s:A", "A", .struct, at: (10, 1)),
            def("s:B", "B", .class, at: (20, 1)),
            def("s:C", "C", .enum, at: (30, 1)),
            ref("s:P", kind: .protocol, at: (10, 11), baseOf: "s:A"),
            ref("s:P", kind: .protocol, at: (20, 10), baseOf: "s:B"),
            ref("s:P", kind: .protocol, at: (30, 10), baseOf: "s:C"),
        ]
        let (graph, _) = build(records)
        #expect(graph.fanIn(of: "s:P") == 3)
        #expect(graph.fanOut(of: "s:P") == 0)
    }

    @Test("Relation-free references attribute by source location")
    func locationFallback() {
        // `case wrapped(Outer)` - the Outer reference carries no relations;
        // its position inside Payload's syntax range attributes it.
        let records = [
            def("s:Outer", "Outer", .struct, at: (1, 8)),
            def("s:Payload", "Payload", .enum, at: (32, 6)),
            ref("s:Outer", at: (33, 18)),
        ]
        let ranges = ["A.swift": rangeIndex("Payload", lines: 32...35)]
        let (graph, diagnostics) = build(records, typeRanges: ranges)
        #expect(graph.outEdges["s:Payload"] == ["s:Outer"])
        #expect(diagnostics.attributedByLocation == 1)
    }

    @Test("Location fallback refuses ambiguous names without a same-file match")
    func locationFallbackAmbiguity() {
        // Two types named "Payload" in other files; the reference sits in a
        // third file whose range says "Payload" - guessing would risk a wrong
        // edge, so the reference is dropped.
        let records = [
            def("s:P1", "Payload", .enum, file: "B.swift"),
            def("s:P2", "Payload", .enum, file: "C.swift"),
            def("s:Outer", "Outer", .struct, at: (1, 8)),
            ref("s:Outer", at: (33, 18)),
        ]
        let ranges = ["A.swift": rangeIndex("Payload", lines: 32...35)]
        let (graph, diagnostics) = build(records, typeRanges: ranges)
        #expect(graph.outEdges.isEmpty)
        #expect(diagnostics.droppedUnattributable == 1)

        // With one candidate in the same file, resolution succeeds.
        let sameFile = [
            def("s:P3", "Payload", .enum, at: (32, 6)),
            def("s:P1", "Payload", .enum, file: "B.swift"),
            def("s:Outer", "Outer", .struct, at: (1, 8)),
            ref("s:Outer", at: (33, 18)),
        ]
        let (resolved, _) = build(sameFile, typeRanges: ranges)
        #expect(resolved.outEdges["s:P3"] == ["s:Outer"])
    }

    @Test("Typealias references are excluded and counted")
    func typealiasExcluded() {
        let records = [
            def("s:A", "A", .struct),
            def("s:A.m", "m()", .instanceMethod, childOf: "s:A"),
            def("s:Alias", "Alias", .typealias, at: (40, 1)),
            ref("s:Alias", kind: .typealias, containedBy: "s:A.m"),
        ]
        let (graph, diagnostics) = build(records)
        #expect(graph.outEdges.isEmpty)
        #expect(diagnostics.droppedTypealias == 1)
    }

    @Test("References with no attribution evidence drop without throwing")
    func unattributableDropped() {
        let records = [
            def("s:B", "B", .struct, at: (10, 1)),
            // No relations, and no syntax range covers the location.
            ref("s:B", at: (99, 1)),
        ]
        let (graph, diagnostics) = build(records)
        #expect(graph.outEdges.isEmpty)
        #expect(diagnostics.droppedUnattributable == 1)
    }

    @Test("containedBy wins over baseOf: one reference, one edge")
    func containedByBeatsBaseOf() {
        let records = [
            def("s:P", "P", .protocol),
            def("s:Foo", "Foo", .struct, at: (10, 1)),
            def("s:Foo.m", "m()", .instanceMethod, at: (11, 5), childOf: "s:Foo"),
            ref("s:P", kind: .protocol, containedBy: "s:Foo.m", baseOf: "s:Foo"),
        ]
        let (graph, diagnostics) = build(records)
        #expect(graph.outEdges["s:Foo"] == ["s:P"])
        #expect(diagnostics.attributedByContainedBy == 1)
        #expect(diagnostics.attributedByBaseOf == 0)
    }

    @Test("Diagnostics buckets partition every reference")
    func diagnosticsInvariant() {
        let records = [
            def("s:P", "P", .protocol),
            def("s:A", "A", .struct, at: (10, 1)),
            def("s:A.m", "m()", .instanceMethod, at: (11, 5), childOf: "s:A"),
            def("s:B", "B", .struct, at: (20, 1)),
            def("s:Alias", "Alias", .typealias, at: (40, 1)),
            def("s:Payload", "Payload", .enum, at: (32, 6)),
            ref("s:B", containedBy: "s:A.m"),  // containedBy
            ref("s:P", kind: .protocol, at: (10, 11), baseOf: "s:A"),  // baseOf
            ref("s:B", at: (33, 18)),  // location (inside Payload)
            ref("s:Swift.Int", at: (51, 1), containedBy: "s:A.m"),  // non-project
            ref("s:Alias", kind: .typealias, at: (52, 1), containedBy: "s:A.m"),  // typealias
            ref("s:B", at: (99, 1)),  // unattributable
            ref("s:A", at: (53, 1), containedBy: "s:A.m"),  // self reference
        ]
        let ranges = ["A.swift": rangeIndex("Payload", lines: 32...35)]
        let (_, d) = build(records, typeRanges: ranges)

        #expect(d.refsTotal == 7)
        #expect(d.attributedByContainedBy == 2)  // edge to B + self reference
        #expect(d.attributedByBaseOf == 1)
        #expect(d.attributedByLocation == 1)
        #expect(d.droppedNonProjectSymbol == 1)
        #expect(d.droppedTypealias == 1)
        #expect(d.droppedUnattributable == 1)
        #expect(d.selfReferencesSkipped == 1)
        // The invariant documented on CouplingDiagnostics.
        let attributed = d.attributedByContainedBy + d.attributedByBaseOf + d.attributedByLocation
        let dropped = d.droppedNonProjectSymbol + d.droppedTypealias + d.droppedUnattributable
        #expect(d.refsTotal == attributed + dropped)
    }
}
