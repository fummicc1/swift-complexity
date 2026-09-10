import Foundation

/// Semantic coupling metrics for one nominal type, measured over the
/// project-internal reference graph (IndexStoreDB).
public struct TypeCoupling: Codable, Hashable, Sendable {
    /// Display name; nested types use dotted form (e.g. "Outer.Inner").
    public let name: String

    /// Declaration kind. Sourced from syntax so actors are reported as
    /// `.actor` even though the index classifies them as classes.
    public let kind: NominalType

    /// Number of distinct project-internal types that reference this type
    /// (afferent coupling). High fan-in means changes here have a large
    /// blast radius.
    public let fanIn: Int

    /// Number of distinct project-internal types this type references
    /// (efferent coupling). High fan-out means this type is easily broken
    /// by changes elsewhere.
    public let fanOut: Int

    /// Martin's instability: fanOut / (fanIn + fanOut), in 0...1.
    /// `nil` when the type has no project-internal coupling at all
    /// (both counts are zero), where the ratio is undefined.
    public let instability: Double?

    /// Location of the type declaration.
    public let location: SourceLocation

    /// Metrics excluded from threshold checks by a `// swift-complexity:disable`
    /// comment above the type declaration. Values are still reported even when
    /// suppressed; only the threshold judgment is skipped.
    public let suppressedMetrics: Set<SuppressedMetric>?

    /// Instability is always derived from the counts rather than accepted as
    /// input, so a `TypeCoupling` can never carry an inconsistent ratio.
    public init(
        name: String,
        kind: NominalType,
        fanIn: Int,
        fanOut: Int,
        location: SourceLocation,
        suppressedMetrics: Set<SuppressedMetric>? = nil
    ) {
        self.name = name
        self.kind = kind
        self.fanIn = fanIn
        self.fanOut = fanOut
        let total = fanIn + fanOut
        self.instability = total == 0 ? nil : Double(fanOut) / Double(total)
        self.location = location
        self.suppressedMetrics = suppressedMetrics
    }

    /// Whether `metric` is suppressed for this type.
    public func isSuppressed(_ metric: SuppressedMetric) -> Bool {
        suppressedMetrics?.contains(metric) ?? false
    }
}

extension TypeCoupling: CustomStringConvertible {
    public var description: String {
        let instabilityText = instability.map { String(format: "%.2f", $0) } ?? "-"
        return
            "\(name) (\(kind.rawValue)) - Fan-In: \(fanIn), Fan-Out: \(fanOut), Instability: \(instabilityText)"
    }
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

/// Aggregated coupling statistics for one file's types.
public struct CouplingSummary: Codable, Sendable {
    public let totalTypes: Int
    public let maxFanIn: Int
    public let maxFanOut: Int
    public let averageFanOut: Double

    public init(types: [TypeCoupling]) {
        self.totalTypes = types.count
        self.maxFanIn = types.map(\.fanIn).max() ?? 0
        self.maxFanOut = types.map(\.fanOut).max() ?? 0
        self.averageFanOut =
            types.isEmpty
            ? 0.0 : Double(types.reduce(0) { $0 + $1.fanOut }) / Double(types.count)
    }
}
