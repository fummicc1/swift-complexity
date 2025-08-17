import Foundation

/// Represents a location in source code
public struct SourceLocation: Codable, Hashable, Sendable {
  /// Line number (1-based)
  public let line: Int

  /// Column number (1-based)
  public let column: Int

  public init(line: Int, column: Int) {
    self.line = line
    self.column = column
  }
}

extension SourceLocation: CustomStringConvertible {
  public var description: String {
    "\(line):\(column)"
  }
}
