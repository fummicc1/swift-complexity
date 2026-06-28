import Foundation

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

    public init(
        name: String,
        signature: String,
        cyclomaticComplexity: Int,
        cognitiveComplexity: Int,
        location: SourceLocation,
        enclosingTypeName: String? = nil
    ) {
        self.name = name
        self.signature = signature
        self.cyclomaticComplexity = cyclomaticComplexity
        self.cognitiveComplexity = cognitiveComplexity
        self.location = location
        self.enclosingTypeName = enclosingTypeName
    }
}

extension FunctionComplexity: CustomStringConvertible {
    public var description: String {
        "\(name) - Cyclomatic: \(cyclomaticComplexity), Cognitive: \(cognitiveComplexity) at \(location)"
    }
}
