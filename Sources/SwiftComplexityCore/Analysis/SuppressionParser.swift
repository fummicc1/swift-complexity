import SwiftSyntax

/// Scans a declaration's leading trivia for `// swift-complexity:disable` comments.
///
/// The comment must be the closest leading `//` comment directly above the
/// declaration it suppresses; there is no separate "next line" form and no
/// "enable" counterpart, because suppression always applies to exactly the
/// one declaration whose leading trivia contains the comment. Only plain
/// `//` line comments are recognized; `///` doc comments are ignored so
/// documentation is never mistaken for a directive.
enum SuppressionParser {
    private static let marker = "swift-complexity:disable"

    /// Returns the set of metrics suppressed by any `swift-complexity:disable`
    /// comment found in `trivia`. Empty when no such comment is present.
    static func suppressedMetrics(in trivia: Trivia) -> Set<SuppressedMetric> {
        var result: Set<SuppressedMetric> = []
        for piece in trivia {
            guard case .lineComment(let text) = piece,
                let metrics = parseDirective(from: text)
            else { continue }
            result.formUnion(metrics)
        }
        return result
    }

    /// Parses a single `//`-prefixed comment. Returns `nil` when the comment
    /// is not a swift-complexity directive at all.
    ///
    /// - A bare directive (nothing but whitespace after the marker) suppresses
    ///   every metric.
    /// - A directive followed by metric names suppresses exactly the
    ///   recognized ones. Unrecognized tokens are ignored, and if none of them
    ///   are recognized, nothing is suppressed — suppression fails closed on a
    ///   typo rather than silently disabling every metric.
    private static func parseDirective(from commentText: String) -> Set<SuppressedMetric>? {
        guard commentText.hasPrefix("//") else { return nil }
        let content = commentText.dropFirst(2).trimmingCharacters(in: .whitespaces)

        guard content.hasPrefix(marker) else { return nil }
        let afterMarker = content.dropFirst(marker.count)

        // Reject a false-prefix match like "disableFoo", which is a different
        // (unsupported) directive, not a typo'd form of "disable".
        if let firstChar = afterMarker.first, firstChar.isLetter || firstChar.isNumber {
            return nil
        }

        let remainder = afterMarker.trimmingCharacters(in: .whitespaces)
        guard !remainder.isEmpty else { return Set(SuppressedMetric.allCases) }

        let tokens = remainder.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\t" })
        return Set(tokens.compactMap { SuppressedMetric(rawValue: String($0)) })
    }
}
