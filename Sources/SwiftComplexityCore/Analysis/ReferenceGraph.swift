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

/// Attribution accounting for one build. Every reference lands in exactly one
/// attributed/dropped bucket, so:
/// refsTotal == attributedByContainedBy + attributedByBaseOf
///            + attributedByLocation + droppedNonProjectSymbol
///            + droppedTypealias + droppedUnattributable.
/// Self-references are attributed but produce no edge; they are additionally
/// counted in `selfReferencesSkipped`.
struct CouplingDiagnostics: Sendable, Equatable {
    var refsTotal = 0
    var attributedByContainedBy = 0
    var attributedByBaseOf = 0
    var attributedByLocation = 0
    var droppedNonProjectSymbol = 0
    var droppedTypealias = 0
    var droppedUnattributable = 0
    var selfReferencesSkipped = 0
}

// MARK: - Builder

/// Builds the type reference graph from index occurrences plus per-file
/// syntax ranges. Pure: no IndexStoreDB queries happen here.
enum ReferenceGraphBuilder {

    /// Index kinds that appear as nominal type definitions. Actors are
    /// indexed as classes; the syntax side corrects the display kind.
    private static let typeKinds: Set<IndexSymbolKind> = [.class, .struct, .enum, .protocol]

    static func build(
        occurrences: [IndexOccurrenceRecord],
        typeRanges: [String: TypeRangeIndex]
    ) -> (graph: ReferenceGraph, diagnostics: CouplingDiagnostics) {
        var diagnostics = CouplingDiagnostics()

        // Pass 1: definitions, parent chains, and extension resolution.
        var defs: [String: IndexOccurrenceRecord] = [:]
        var parentOf: [String: String] = [:]
        var extensionToType: [String: String] = [:]

        for record in occurrences {
            if record.roles.contains(.definition) {
                defs[record.usr] = record
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

        let typeUSRs = Set(defs.values.filter { typeKinds.contains($0.kind) }.map(\.usr))

        /// Walks a symbol up to its owning nominal type: extensions resolve to
        /// the extended type, members resolve through childOf parents. The
        /// depth cap turns corrupt parent cycles into a dropped ref instead of
        /// a hang.
        func ownerType(_ usr: String) -> String? {
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

        // Node construction: join index definitions with syntax ranges for
        // dotted names, actor kinds, and suppression. Runs before the
        // reference pass because location-based attribution needs the
        // name-to-USR mapping.
        var nodes: [String: ReferenceGraph.Node] = [:]
        for usr in typeUSRs {
            guard let def = defs[usr] else { continue }
            let entry = typeRanges[def.file]?.innermostType(line: def.line, column: def.column)

            let kind: NominalType
            if case .nominal(let syntaxKind)? = entry?.declKind {
                kind = syntaxKind
            } else {
                kind = Self.fallbackKind(for: def.kind)
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

        var typeUSRsByName: [String: [String]] = [:]
        for node in nodes.values {
            typeUSRsByName[node.name, default: []].append(node.usr)
        }

        /// Maps a syntax type name back to a USR. Same-file candidates win;
        /// an ambiguous name with no same-file candidate resolves to nil
        /// rather than guessing a wrong edge.
        func typeUSR(named name: String, inFile file: String) -> String? {
            guard let candidates = typeUSRsByName[name] else { return nil }
            if let sameFile = candidates.first(where: { nodes[$0]?.file == file }),
                candidates.filter({ nodes[$0]?.file == file }).count == 1
            {
                return sameFile
            }
            return candidates.count == 1 ? candidates[0] : nil
        }

        // Pass 2: references become type-to-type edges.
        var outEdges: [String: Set<String>] = [:]
        var inEdges: [String: Set<String>] = [:]

        for record in occurrences
        where record.roles.contains(.reference) || record.roles.contains(.call) {
            diagnostics.refsTotal += 1

            // Typealias references are excluded from coupling: resolving
            // through the alias would need semantic type information the
            // index does not expose directly.
            if record.kind == .typealias {
                diagnostics.droppedTypealias += 1
                continue
            }

            // Target side: the referenced type, or the type owning the
            // referenced member.
            guard defs[record.usr] != nil else {
                diagnostics.droppedNonProjectSymbol += 1
                continue
            }
            guard let target = ownerType(record.usr) else {
                diagnostics.droppedUnattributable += 1
                continue
            }

            // Source side: who holds this reference. Attribution cascades
            // from the most to the least semantic evidence:
            // 1. containedBy - the reference sits inside a declaration.
            // 2. baseOf - inheritance/conformance clauses carry only this
            //    relation, pointing at the inheriting type.
            // 3. Syntax location - e.g. enum case payload annotations carry
            //    no relations at all.
            let source: String?
            if let container = record.relations.first(where: { $0.roles.contains(.containedBy) }),
                let resolved = ownerType(container.usr)
            {
                source = resolved
                diagnostics.attributedByContainedBy += 1
            } else if let base = record.relations.first(where: { $0.roles.contains(.baseOf) }),
                let resolved = ownerType(base.usr)
            {
                source = resolved
                diagnostics.attributedByBaseOf += 1
            } else if let entry = typeRanges[record.file]?.innermostType(
                line: record.line, column: record.column),
                let resolved = typeUSR(named: entry.resolvedTypeName, inFile: record.file)
            {
                source = resolved
                diagnostics.attributedByLocation += 1
            } else {
                source = nil
            }

            guard let source else {
                diagnostics.droppedUnattributable += 1
                continue
            }

            if source == target {
                diagnostics.selfReferencesSkipped += 1
                continue
            }
            outEdges[source, default: []].insert(target)
            inEdges[target, default: []].insert(source)
        }

        let graph = ReferenceGraph(nodes: nodes, outEdges: outEdges, inEdges: inEdges)
        return (graph, diagnostics)
    }

    private static func fallbackKind(for indexKind: IndexSymbolKind) -> NominalType {
        switch indexKind {
        case .struct: return .struct
        case .enum: return .enum
        case .protocol: return .protocol
        default: return .class
        }
    }
}
