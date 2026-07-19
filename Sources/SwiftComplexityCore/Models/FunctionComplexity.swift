import Foundation

/// A metric that can be excluded from threshold checks via a
/// `// swift-complexity:disable` comment.
///
/// `cyclomatic`/`cognitive` apply to function-level declarations,
/// `lcom4` to type declarations (class/struct/actor). Which subset a
/// directive can actually suppress is decided by the declaration it
/// precedes — see `SuppressedMetric.functionLevel`/`typeLevel`.
public enum SuppressedMetric: String, Codable, Hashable, Sendable, CaseIterable {
    case cyclomatic
    case cognitive
    case lcom4
}

extension SuppressedMetric {
    /// Metrics a directive above a function-level declaration can suppress.
    public static let functionLevel: Set<SuppressedMetric> = [.cyclomatic, .cognitive]

    /// Metrics a directive above a type declaration can suppress.
    public static let typeLevel: Set<SuppressedMetric> = [.lcom4]
}

/// Represents complexity metrics for a single function or method
public struct FunctionComplexity: Codable, Hashable, Sendable {
    /// Function or method name
    public let name: String

    /// Function signature for disambiguation
    public let signature: String

    /// Cyclomatic complexity value
    public let cyclomaticComplexity: Int

    /// Cognitive complexity value
    public let cognitiveComplexity: Int

    /// Location in source code
    public let location: SourceLocation

    /// Name of the nearest enclosing nominal type (class/struct/enum/actor) or the
    /// extended type for extensions. `nil` for free (top-level) functions.
    ///
    /// Used to resolve per-type complexity thresholds. Optional for backward
    /// compatibility with previously encoded results.
    public let enclosingTypeName: String?

    /// Metrics excluded from threshold checks by a `// swift-complexity:disable`
    /// comment directly above this declaration. `nil` when nothing is
    /// suppressed; values are still reported even when suppressed, only the
    /// threshold judgment is skipped.
    public let suppressedMetrics: Set<SuppressedMetric>?

    public init(
        name: String,
        signature: String,
        cyclomaticComplexity: Int,
        cognitiveComplexity: Int,
        location: SourceLocation,
        enclosingTypeName: String? = nil,
        suppressedMetrics: Set<SuppressedMetric>? = nil
    ) {
        self.name = name
        self.signature = signature
        self.cyclomaticComplexity = cyclomaticComplexity
        self.cognitiveComplexity = cognitiveComplexity
        self.location = location
        self.enclosingTypeName = enclosingTypeName
        self.suppressedMetrics = suppressedMetrics
    }

    /// Whether `metric` is suppressed for this function.
    public func isSuppressed(_ metric: SuppressedMetric) -> Bool {
        suppressedMetrics?.contains(metric) ?? false
    }
}

extension FunctionComplexity: CustomStringConvertible {
    public var description: String {
        "\(name) - Cyclomatic: \(cyclomaticComplexity), Cognitive: \(cognitiveComplexity) at \(location)"
    }
}
