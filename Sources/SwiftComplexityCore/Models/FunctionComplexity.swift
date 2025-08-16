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

    public init(
        name: String,
        signature: String,
        cyclomaticComplexity: Int,
        cognitiveComplexity: Int,
        location: SourceLocation
    ) {
        self.name = name
        self.signature = signature
        self.cyclomaticComplexity = cyclomaticComplexity
        self.cognitiveComplexity = cognitiveComplexity
        self.location = location
    }
}

extension FunctionComplexity: CustomStringConvertible {
    public var description: String {
        "\(name) - Cyclomatic: \(cyclomaticComplexity), Cognitive: \(cognitiveComplexity) at \(location)"
    }
}
