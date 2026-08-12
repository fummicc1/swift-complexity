import Foundation
import IndexStoreDB

/// Computes type-level coupling in one whole-project pass.
///
/// A thin adapter: scans the index occurrences of every analyzed file,
/// projects them into pure records, and delegates all attribution logic to
/// `ReferenceGraphBuilder` (which is what the unit tests cover).
actor TypeCouplingCalculator {
    private let indexStore: SharedIndexStore

    init(indexStore: SharedIndexStore) {
        self.indexStore = indexStore
    }

    /// - Parameters:
    ///   - analyzedFiles: All Swift files in this run; defines the
    ///     project-internal type population.
    ///   - typeRanges: Per-file syntax ranges from `TypeRangeCollector`.
    /// - Returns: Couplings grouped by the file defining each type (sorted by
    ///   location for deterministic output), plus attribution accounting.
    func calculate(
        analyzedFiles: [String],
        typeRanges: [String: TypeRangeIndex]
    ) -> (byFile: [String: [TypeCoupling]], diagnostics: CouplingDiagnostics) {
        var records: [IndexOccurrenceRecord] = []
        for file in analyzedFiles {
            for occurrence in indexStore.database.symbolOccurrences(inFilePath: file) {
                records.append(
                    IndexOccurrenceRecord(
                        usr: occurrence.symbol.usr,
                        name: occurrence.symbol.name,
                        kind: occurrence.symbol.kind,
                        // The query path, not occurrence.location.path: it is
                        // guaranteed to match typeRanges keys and the result
                        // file paths.
                        file: file,
                        line: occurrence.location.line,
                        column: occurrence.location.utf8Column,
                        roles: occurrence.roles,
                        relations: occurrence.relations.map {
                            RecordRelation(
                                usr: $0.symbol.usr, kind: $0.symbol.kind, roles: $0.roles)
                        }
                    ))
            }
        }

        let (graph, diagnostics) = ReferenceGraphBuilder.build(
            occurrences: records, typeRanges: typeRanges)

        var byFile: [String: [TypeCoupling]] = [:]
        for node in graph.nodes.values {
            byFile[node.file, default: []].append(
                TypeCoupling(
                    name: node.name,
                    kind: node.kind,
                    fanIn: graph.fanIn(of: node.usr),
                    fanOut: graph.fanOut(of: node.usr),
                    location: node.location,
                    suppressedMetrics: node.suppressedMetrics.isEmpty
                        ? nil : node.suppressedMetrics
                ))
        }
        for (file, couplings) in byFile {
            byFile[file] = couplings.sorted {
                ($0.location.line, $0.location.column, $0.name)
                    < ($1.location.line, $1.location.column, $1.name)
            }
        }

        return (byFile, diagnostics)
    }
}
