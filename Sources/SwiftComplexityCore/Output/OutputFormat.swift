import Foundation

/// Available output formats for complexity analysis results
public enum OutputFormat: String, CaseIterable {
    case text
    case json
    case xml
    case xcode  // Xcode diagnostics format

    public static var help: String {
        let descriptions = allCases.map { format in
            "\(format.rawValue): \(format.detailedDescription)"
        }
        return descriptions.joined(separator: ", ")
    }

    private var detailedDescription: String {
        switch self {
        case .text:
            return "Human-readable text format"
        case .json:
            return "JSON format for machine processing"
        case .xml:
            return "XML format for report tools"
        case .xcode:
            return "Xcode diagnostics format for IDE integration"
        }
    }

    public static var allValueStrings: [String] {
        return allCases.map(\.rawValue)
    }
}

extension OutputFormat: CustomStringConvertible {
    public var description: String {
        return rawValue
    }
}
