import Foundation
import Yams

/// A single per-type complexity threshold rule.
///
/// A rule matches a nominal type by its name using an optional `prefix` and/or
/// `suffix`. When both are specified, both must match. A rule with neither
/// `prefix` nor `suffix` is considered invalid and never matches, because it
/// would otherwise apply to every type and make the configuration ambiguous.
public struct ThresholdRule: Codable, Sendable, Hashable {
    /// Match types whose name starts with this string (e.g. `Toilet` → `ToiletRepository`).
    public let prefix: String?

    /// Match types whose name ends with this string (e.g. `Repository` → `UserRepository`).
    public let suffix: String?

    /// Complexity threshold applied to functions of the matched type.
    public let threshold: Int

    public init(prefix: String? = nil, suffix: String? = nil, threshold: Int) {
        self.prefix = prefix
        self.suffix = suffix
        self.threshold = threshold
    }

    /// Returns whether this rule matches the given type name.
    ///
    /// A rule without any `prefix` or `suffix` never matches: such a rule has no
    /// selector, so applying it to all types would be surprising.
    public func matches(typeName: String) -> Bool {
        guard prefix != nil || suffix != nil else { return false }

        let prefixMatches = prefix.map { typeName.hasPrefix($0) } ?? true
        let suffixMatches = suffix.map { typeName.hasSuffix($0) } ?? true
        return prefixMatches && suffixMatches
    }
}

/// Type-level coupling thresholds.
///
/// Absent keys mean "report-only": the metric is measured and reported but
/// never gates the exit code. No defaults ship on purpose — unlike cyclomatic
/// complexity's established 10/20 convention, sensible fan-in/fan-out limits
/// depend on codebase size, and a wrong default would flood adopters with
/// noise.
public struct CouplingThresholds: Codable, Sendable, Equatable {
    /// Flag types whose fan-out reaches this value (efferent coupling).
    public let fanOut: Int?

    /// Flag types whose fan-in reaches this value (afferent coupling).
    /// Prefer starting with `fanOut`: high fan-in alone is often healthy
    /// (stable shared models) and is better judged via the hotspot ranking.
    public let fanIn: Int?

    public init(fanOut: Int? = nil, fanIn: Int? = nil) {
        self.fanOut = fanOut
        self.fanIn = fanIn
    }
}

/// One coupling threshold violation for a type.
public struct CouplingViolation: Sendable, Equatable {
    public enum Metric: String, Sendable {
        case fanOut
        case fanIn
    }

    public let metric: Metric
    public let value: Int
    public let threshold: Int
}

/// Per-type complexity threshold configuration.
///
/// Loaded from a `.swift-complexity.yml` file. Functions are flagged using a
/// threshold resolved from their enclosing type name: among all matching rules
/// the strictest (lowest) threshold wins. Types matching no rule fall back to
/// the caller-provided value (typically the CLI `--threshold`) or, failing that,
/// `defaultThreshold`.
public struct ThresholdConfiguration: Codable, Sendable, Equatable {
    /// Fallback threshold for types/functions that match no rule. Optional.
    public let defaultThreshold: Int?

    /// Ordered list of per-type threshold rules.
    public let rules: [ThresholdRule]

    /// Optional coupling thresholds. `nil` (key absent) keeps coupling
    /// report-only, preserving the behavior of configurations written before
    /// coupling metrics existed.
    public let coupling: CouplingThresholds?

    public init(
        defaultThreshold: Int? = nil,
        rules: [ThresholdRule] = [],
        coupling: CouplingThresholds? = nil
    ) {
        self.defaultThreshold = defaultThreshold
        self.rules = rules
        self.coupling = coupling
    }

    /// Every key is optional: a configuration that only sets `coupling:` (or
    /// only `defaultThreshold:`) is valid. The synthesized decoder would
    /// reject files without a `rules:` key.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.defaultThreshold = try container.decodeIfPresent(
            Int.self, forKey: .defaultThreshold)
        self.rules = try container.decodeIfPresent([ThresholdRule].self, forKey: .rules) ?? []
        self.coupling = try container.decodeIfPresent(
            CouplingThresholds.self, forKey: .coupling)
    }

    /// An empty configuration that defines no rules. Resolution then depends
    /// solely on the caller-provided fallback, preserving legacy behavior.
    public static let empty = ThresholdConfiguration()

    /// Whether this configuration carries no rules and no default threshold.
    ///
    /// Deliberately ignores `coupling`: every existing `isEmpty` call site
    /// gates complexity-threshold behavior (SARIF warnings, result
    /// filtering), which a coupling-only configuration must not change.
    public var isEmpty: Bool {
        defaultThreshold == nil && rules.isEmpty
    }

    /// Coupling threshold violations for `type`, using the same `>=` semantics
    /// as the complexity exit-code check. Suppression excludes the type from
    /// the judgment entirely; its values are still reported elsewhere.
    public func couplingViolations(_ type: TypeCoupling) -> [CouplingViolation] {
        guard let coupling, !type.isSuppressed(.coupling) else { return [] }

        var violations: [CouplingViolation] = []
        if let limit = coupling.fanOut, type.fanOut >= limit {
            violations.append(.init(metric: .fanOut, value: type.fanOut, threshold: limit))
        }
        if let limit = coupling.fanIn, type.fanIn >= limit {
            violations.append(.init(metric: .fanIn, value: type.fanIn, threshold: limit))
        }
        return violations
    }

    /// Resolves the effective complexity threshold for a function whose
    /// enclosing type is `typeName`.
    ///
    /// - Parameters:
    ///   - typeName: The nearest enclosing nominal type name, or `nil` for a
    ///     free (top-level) function.
    ///   - fallback: A caller-supplied threshold (e.g. the CLI `--threshold`)
    ///     that overrides `defaultThreshold` for unmatched types.
    /// - Returns: The strictest matching rule threshold, otherwise
    ///   `fallback ?? defaultThreshold`, otherwise `nil` (no threshold → never flagged).
    public func threshold(forTypeName typeName: String?, fallback: Int?) -> Int? {
        if let typeName {
            let matched = rules.filter { $0.matches(typeName: typeName) }.map(\.threshold)
            if let strictest = matched.min() {
                return strictest
            }
        }
        return fallback ?? defaultThreshold
    }

    /// Whether the given function exceeds its effective threshold.
    ///
    /// Mirrors the legacy semantics: a function is flagged when either its
    /// cyclomatic or cognitive complexity reaches the threshold. A metric
    /// suppressed via `// swift-complexity:disable` is excluded from this
    /// check; its value is still reported elsewhere, only the judgment is
    /// skipped.
    public func isExceeded(_ function: FunctionComplexity, fallback: Int?) -> Bool {
        guard
            let threshold = threshold(forTypeName: function.enclosingTypeName, fallback: fallback)
        else {
            return false
        }
        return (!function.isSuppressed(.cyclomatic) && function.cyclomaticComplexity >= threshold)
            || (!function.isSuppressed(.cognitive) && function.cognitiveComplexity >= threshold)
    }

    // MARK: - Loading

    /// Errors thrown while loading a threshold configuration.
    public enum LoadError: Error, LocalizedError {
        case fileNotFound(String)
        case decodingFailed(String)

        public var errorDescription: String? {
            switch self {
            case .fileNotFound(let path):
                return "Configuration file not found: \(path)"
            case .decodingFailed(let message):
                return "Failed to decode configuration: \(message)"
            }
        }
    }

    /// Loads configuration from a YAML file at the given path.
    public static func load(fromFileAtPath path: String) throws -> ThresholdConfiguration {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw LoadError.fileNotFound(path)
        }
        return try load(from: url)
    }

    /// Loads configuration from a YAML file URL.
    public static func load(from url: URL) throws -> ThresholdConfiguration {
        let yaml = try String(contentsOf: url, encoding: .utf8)
        do {
            return try YAMLDecoder().decode(ThresholdConfiguration.self, from: yaml)
        } catch {
            throw LoadError.decodingFailed(error.localizedDescription)
        }
    }

    /// Default configuration file name searched in the current working directory.
    public static let defaultFileName = ".swift-complexity.yml"

    /// Discovers a configuration file in `directory` (default: current directory),
    /// trying `.swift-complexity.yml` then `.swift-complexity.yaml`. Returns `nil`
    /// when no file is present.
    public static func discover(in directory: String = FileManager.default.currentDirectoryPath)
        throws -> ThresholdConfiguration?
    {
        let candidates = [".swift-complexity.yml", ".swift-complexity.yaml"]
        for candidate in candidates {
            let url = URL(fileURLWithPath: directory).appendingPathComponent(candidate)
            if FileManager.default.fileExists(atPath: url.path) {
                return try load(from: url)
            }
        }
        return nil
    }
}
