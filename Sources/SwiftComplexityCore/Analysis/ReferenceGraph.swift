import Foundation
import IndexStoreDB

// MARK: - Pure input records

/// One relation attached to an index occurrence.
struct RecordRelation: Sendable {
    let usr: String
    let kind: IndexSymbolKind
    let roles: SymbolRole
}

/// A pure-data projection of `SymbolOccurrence`.
///
/// The graph builder consumes these instead of IndexStoreDB types that
/// require a live store, so the whole attribution algorithm is unit-testable
/// with hand-written records (relation shapes were verified against a real
/// index in the coupling spike).
struct IndexOccurrenceRecord: Sendable {
    let usr: String
    let name: String
    let kind: IndexSymbolKind
    let file: String
    let line: Int
    let column: Int
    let roles: SymbolRole
    let relations: [RecordRelation]
}

// MARK: - Outputs

/// Type-to-type reference graph over project-internal nominal types.
struct ReferenceGraph: Sendable {
    struct Node: Sendable {
        let usr: String
        /// Dotted display name from syntax when available (e.g. "Outer.Inner"),
        /// otherwise the index symbol name.
        let name: String
        /// Syntax-derived kind when available: the index reports actors as
        /// classes, so syntax wins.
        let kind: NominalType
        let file: String
        let location: SourceLocation
        let suppressedMetrics: Set<SuppressedMetric>
    }

    /// Project-internal types only, keyed by USR.
    let nodes: [String: Node]
    let outEdges: [String: Set<String>]
    let inEdges: [String: Set<String>]

    func fanOut(of usr: String) -> Int { outEdges[usr]?.count ?? 0 }
    func fanIn(of usr: String) -> Int { inEdges[usr]?.count ?? 0 }
}

/// Attribution accounting for one coupling run. Every reference lands in
/// exactly one attributed/dropped bucket, so:
/// refsTotal == attributedByContainedBy + attributedByBaseOf
///            + attributedByLocation + droppedNonProjectSymbol
///            + droppedTypealias + droppedUnattributable.
/// Self-references are attributed but produce no edge; they are additionally
/// counted in `selfReferencesSkipped`.
///
/// Public so the CLI can report attribution quality to stderr; construction
/// and mutation stay internal to the analysis.
public struct CouplingDiagnostics: Sendable, Equatable {
    public internal(set) var refsTotal = 0
    public internal(set) var attributedByContainedBy = 0
    public internal(set) var attributedByBaseOf = 0
    public internal(set) var attributedByLocation = 0
    public internal(set) var droppedNonProjectSymbol = 0
    public internal(set) var droppedTypealias = 0
    public internal(set) var droppedUnattributable = 0
    public internal(set) var selfReferencesSkipped = 0

    /// References that resolved to a source type (self-references included).
    public var attributedTotal: Int {
        attributedByContainedBy + attributedByBaseOf + attributedByLocation
    }
}

// MARK: - Definition index (pass 1)

/// Definitions, parent chains, and extension resolution collected in one pass
/// over the occurrences.
private struct DefinitionIndex {
    /// Index kinds that appear as nominal type definitions. Actors are
    /// indexed as classes; the syntax side corrects the display kind.
    static let typeKinds: Set<IndexSymbolKind> = [.class, .struct, .enum, .protocol]

    private(set) var defs: [String: IndexOccurrenceRecord] = [:]
    private(set) var parentOf: [String: String] = [:]
    private(set) var extensionToType: [String: String] = [:]
    private(set) var typeUSRs: Set<String> = []

    init(occurrences: [IndexOccurrenceRecord]) {
        for record in occurrences {
            if record.roles.contains(.definition) {
                defs[record.usr] = record
                if Self.typeKinds.contains(record.kind) {
                    typeUSRs.insert(record.usr)
                }
                if let parent = record.relations.first(where: { $0.roles.contains(.childOf) }) {
                    parentOf[record.usr] = parent.usr
                }
            }
            // The reference to `Foo` in `extension Foo` carries an
            // `extendedBy` relation pointing at the extension symbol.
            if let extRelation = record.relations.first(where: { $0.roles.contains(.extendedBy) }
            ) {
                extensionToType[extRelation.usr] = record.usr
            }
        }
    }

    /// Walks a symbol up to its owning nominal type: extensions resolve to
    /// the extended type, members resolve through childOf parents. The depth
    /// cap turns corrupt parent cycles into a dropped ref instead of a hang.
    func ownerType(of usr: String) -> String? {
        var current = usr
        for _ in 0..<16 {
            if let extended = extensionToType[current] {
                current = extended
                continue
            }
            guard defs[current] != nil else { return nil }
            if typeUSRs.contains(current) { return current }
            guard let parent = parentOf[current] else { return nil }
            current = parent
        }
        return nil
    }
}

// MARK: - Builder

/// Builds the type reference graph from index occurrences plus per-file
/// syntax ranges. Pure: no IndexStoreDB queries happen here.
enum ReferenceGraphBuilder {

    static func build(
        occurrences: [IndexOccurrenceRecord],
        typeRanges: [String: TypeRangeIndex]
    ) -> (graph: ReferenceGraph, diagnostics: CouplingDiagnostics) {
        let index = DefinitionIndex(occurrences: occurrences)
        let nodes = buildNodes(index: index, typeRanges: typeRanges)

        var diagnostics = CouplingDiagnostics()
        var outEdges: [String: Set<String>] = [:]
        var inEdges: [String: Set<String>] = [:]

        for record in occurrences
        where record.roles.contains(.reference) || record.roles.contains(.call) {
            diagnostics.refsTotal += 1
            guard
                let edge = resolveEdge(
                    for: record, index: index, nodes: nodes,
                    typeRanges: typeRanges, diagnostics: &diagnostics)
            else { continue }

            if edge.source == edge.target {
                diagnostics.selfReferencesSkipped += 1
                continue
            }
            outEdges[edge.source, default: []].insert(edge.target)
            inEdges[edge.target, default: []].insert(edge.source)
        }

        let graph = ReferenceGraph(nodes: nodes, outEdges: outEdges, inEdges: inEdges)
        return (graph, diagnostics)
    }

    // MARK: Node metadata

    /// Joins index definitions with syntax ranges for dotted names, actor
    /// kinds, and suppression.
    private static func buildNodes(
        index: DefinitionIndex, typeRanges: [String: TypeRangeIndex]
    ) -> [String: ReferenceGraph.Node] {
        var nodes: [String: ReferenceGraph.Node] = [:]
        for usr in index.typeUSRs {
            guard let def = index.defs[usr] else { continue }
            let entry = typeRanges[def.file]?.innermostType(line: def.line, column: def.column)

            let kind: NominalType
            if case .nominal(let syntaxKind)? = entry?.declKind {
                kind = syntaxKind
            } else {
                kind = fallbackKind(for: def.kind)
            }

            nodes[usr] = ReferenceGraph.Node(
                usr: usr,
                name: entry?.name ?? def.name,
                kind: kind,
                file: def.file,
                location: SourceLocation(line: def.line, column: def.column),
                suppressedMetrics: entry.map(\.suppressedMetrics) ?? []
            )
        }
        return nodes
    }

    private static func fallbackKind(for indexKind: IndexSymbolKind) -> NominalType {
        switch indexKind {
        case .struct: return .struct
        case .enum: return .enum
        case .protocol: return .protocol
        default: return .class
        }
    }

    // MARK: Edge resolution (pass 2)

    /// Resolves one reference into a source/target type pair, or records why
    /// it was dropped.
    private static func resolveEdge(
        for record: IndexOccurrenceRecord,
        index: DefinitionIndex,
        nodes: [String: ReferenceGraph.Node],
        typeRanges: [String: TypeRangeIndex],
        diagnostics: inout CouplingDiagnostics
    ) -> (source: String, target: String)? {
        // Typealias references are excluded from coupling: resolving through
        // the alias would need semantic type information the index does not
        // expose directly.
        if record.kind == .typealias {
            diagnostics.droppedTypealias += 1
            return nil
        }
        guard index.defs[record.usr] != nil else {
            diagnostics.droppedNonProjectSymbol += 1
            return nil
        }
        guard let target = index.ownerType(of: record.usr) else {
            diagnostics.droppedUnattributable += 1
            return nil
        }
        guard
            let source = resolveSource(
                for: record, index: index, nodes: nodes,
                typeRanges: typeRanges, diagnostics: &diagnostics)
        else {
            diagnostics.droppedUnattributable += 1
            return nil
        }
        return (source, target)
    }

    /// Resolves who holds a reference. Attribution cascades from the most to
    /// the least semantic evidence:
    /// 1. containedBy - the reference sits inside a declaration.
    /// 2. baseOf - inheritance/conformance clauses carry only this relation,
    ///    pointing at the inheriting type.
    /// 3. Syntax location - e.g. enum case payload annotations carry no
    ///    relations at all.
    private static func resolveSource(
        for record: IndexOccurrenceRecord,
        index: DefinitionIndex,
        nodes: [String: ReferenceGraph.Node],
        typeRanges: [String: TypeRangeIndex],
        diagnostics: inout CouplingDiagnostics
    ) -> String? {
        if let container = record.relations.first(where: { $0.roles.contains(.containedBy) }),
            let resolved = index.ownerType(of: container.usr)
        {
            diagnostics.attributedByContainedBy += 1
            return resolved
        }
        if let base = record.relations.first(where: { $0.roles.contains(.baseOf) }),
            let resolved = index.ownerType(of: base.usr)
        {
            diagnostics.attributedByBaseOf += 1
            return resolved
        }
        if let entry = typeRanges[record.file]?.innermostType(
            line: record.line, column: record.column),
            let resolved = typeUSR(named: entry.resolvedTypeName, inFile: record.file, nodes: nodes)
        {
            diagnostics.attributedByLocation += 1
            return resolved
        }
        return nil
    }

    /// Maps a syntax type name back to a USR. Exact name matches win over
    /// dotted-suffix matches, same-file candidates win over other files, and
    /// an ambiguous name resolves to nil rather than guessing a wrong edge.
    private static func typeUSR(
        named name: String, inFile file: String, nodes: [String: ReferenceGraph.Node]
    ) -> String? {
        let exact = nodes.values.filter { $0.name == name }
        let candidates =
            exact.isEmpty
            ? nodes.values.filter { $0.name.hasSuffix(".\(name)") }
            : exact
        let sameFile = candidates.filter { $0.file == file }
        if sameFile.count == 1 { return sameFile[0].usr }
        return candidates.count == 1 ? candidates.first?.usr : nil
    }
}
