import MCP

/// Utility for extracting typed values from MCP tool arguments.
enum ParamExtractor {
    static func string(_ key: String, from args: [String: Value]?) -> String? {
        args?[key]?.stringValue
    }

    static func stringArray(_ key: String, from args: [String: Value]?) -> [String]? {
        guard let array = args?[key]?.arrayValue else { return nil }
        return array.compactMap(\.stringValue)
    }

    static func bool(_ key: String, from args: [String: Value]?, default defaultValue: Bool = false)
        -> Bool
    {
        guard let value = args?[key] else { return defaultValue }
        if let b = value.boolValue { return b }
        return defaultValue
    }

    static func int(_ key: String, from args: [String: Value]?) -> Int? {
        guard let value = args?[key] else { return nil }
        if let n = value.intValue { return n }
        return nil
    }
}
