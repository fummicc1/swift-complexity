/// Single source of truth for the swift-complexity release version.
///
/// Referenced by the CLI (`--version`), the MCP server handshake, and the
/// SARIF `tool.driver.version` field so a release bump happens in one place.
public enum SwiftComplexityVersion {
    public static let current = "1.2.1"
}
