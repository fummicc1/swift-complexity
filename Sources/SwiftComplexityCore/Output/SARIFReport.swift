import Foundation

// MARK: - SARIF 2.1.0 Model (minimal subset)

/// Minimal SARIF 2.1.0 document model covering what GitHub Code Scanning
/// requires: tool metadata with rules, and one result per metric violation.
struct SARIFReport: Codable {
    let schema: String
    let version: String
    let runs: [SARIFRun]

    enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case version
        case runs
    }
}

struct SARIFRun: Codable {
    let tool: SARIFTool
    let results: [SARIFResult]
}

struct SARIFTool: Codable {
    let driver: SARIFDriver
}

struct SARIFDriver: Codable {
    let name: String
    let version: String
    let informationUri: String
    let rules: [SARIFRule]
}

struct SARIFRule: Codable {
    let id: String
    let name: String
    let shortDescription: SARIFMessage
    let helpUri: String
}

struct SARIFMessage: Codable {
    let text: String
}

struct SARIFResult: Codable {
    let ruleId: String
    let level: String
    let message: SARIFMessage
    let locations: [SARIFLocation]
}

struct SARIFLocation: Codable {
    let physicalLocation: SARIFPhysicalLocation
}

struct SARIFPhysicalLocation: Codable {
    let artifactLocation: SARIFArtifactLocation
    let region: SARIFRegion
}

struct SARIFArtifactLocation: Codable {
    let uri: String
}

struct SARIFRegion: Codable {
    let startLine: Int
    let startColumn: Int
}

// MARK: - SARIF Formatting

extension OutputFormatter {
    private enum SARIFConstants {
        static let schemaURI = "https://json.schemastore.org/sarif-2.1.0.json"
        static let repositoryURI = "https://github.com/fummicc1/swift-complexity"
        static let metricsHelpURI =
            "https://github.com/fummicc1/swift-complexity/blob/main/docs/user-guide/complexity-metrics.md"

        static let cyclomaticRuleId = "cyclomatic_complexity"
        static let cognitiveRuleId = "cognitive_complexity"
        static let lcom4RuleId = "lcom4_cohesion"
        static let fanOutRuleId = "type_fan_out"
        static let fanInRuleId = "type_fan_in"
    }

    func formatAsSARIF(results: [ComplexityResult], options: OutputOptions) -> String {
        let sarifResults =
            results.flatMap { complexityResults(for: $0, options: options) }
            + results.flatMap { cohesionResults(for: $0) }
            + results.flatMap { couplingResults(for: $0, options: options) }

        let driver = SARIFDriver(
            name: "swift-complexity",
            version: SwiftComplexityVersion.current,
            informationUri: SARIFConstants.repositoryURI,
            rules: sarifRules()
        )
        let report = SARIFReport(
            schema: SARIFConstants.schemaURI,
            version: "2.1.0",
            runs: [SARIFRun(tool: SARIFTool(driver: driver), results: sarifResults)]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        do {
            let data = try encoder.encode(report)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"Failed to encode SARIF: \(error.localizedDescription)\"}"
        }
    }

    private func sarifRules() -> [SARIFRule] {
        [
            SARIFRule(
                id: SARIFConstants.cyclomaticRuleId,
                name: "CyclomaticComplexity",
                shortDescription: SARIFMessage(
                    text: "Cyclomatic complexity should not exceed the configured threshold"),
                helpUri: SARIFConstants.metricsHelpURI
            ),
            SARIFRule(
                id: SARIFConstants.cognitiveRuleId,
                name: "CognitiveComplexity",
                shortDescription: SARIFMessage(
                    text: "Cognitive complexity should not exceed the configured threshold"),
                helpUri: SARIFConstants.metricsHelpURI
            ),
            SARIFRule(
                id: SARIFConstants.lcom4RuleId,
                name: "LCOM4Cohesion",
                shortDescription: SARIFMessage(
                    text: "Classes should not have low cohesion (LCOM4 >= 3)"),
                helpUri: SARIFConstants.metricsHelpURI
            ),
            SARIFRule(
                id: SARIFConstants.fanOutRuleId,
                name: "TypeFanOut",
                shortDescription: SARIFMessage(
                    text: "Types should not depend on more types than the configured fan-out threshold"),
                helpUri: SARIFConstants.metricsHelpURI
            ),
            SARIFRule(
                id: SARIFConstants.fanInRuleId,
                name: "TypeFanIn",
                shortDescription: SARIFMessage(
                    text: "Types should not be depended upon by more types than the configured fan-in threshold"),
                helpUri: SARIFConstants.metricsHelpURI
            ),
        ]
    }

    /// Builds one SARIF result per metric that reaches its effective threshold,
    /// using the same `>=` semantics as the CLI exit-code check so annotations
    /// and CI failures always agree. A metric suppressed via
    /// `// swift-complexity:disable` never produces a result, even if the
    /// overall function still exceeds the threshold on its other metric.
    private func complexityResults(
        for result: ComplexityResult,
        options: OutputOptions
    ) -> [SARIFResult] {
        let uri = relativizedURI(for: result.filePath)

        return result.functions.flatMap { function -> [SARIFResult] in
            let resolved =
                options.thresholdConfiguration?.threshold(
                    forTypeName: function.enclosingTypeName, fallback: options.threshold)
                ?? options.threshold
            guard let threshold = resolved else { return [] }

            let metrics: [(ruleId: String, label: String, metric: SuppressedMetric, value: Int)] = [
                (
                    SARIFConstants.cyclomaticRuleId, "cyclomatic", .cyclomatic,
                    function.cyclomaticComplexity
                ),
                (
                    SARIFConstants.cognitiveRuleId, "cognitive", .cognitive,
                    function.cognitiveComplexity
                ),
            ]

            return metrics.compactMap { metric in
                guard !function.isSuppressed(metric.metric), metric.value >= threshold else {
                    return nil
                }
                let message =
                    "Function '\(function.name)' has \(metric.label) complexity \(metric.value) (threshold: \(threshold))"
                return SARIFResult(
                    ruleId: metric.ruleId,
                    level: metric.value >= threshold * 2 ? "error" : "warning",
                    message: SARIFMessage(text: message),
                    locations: [sarifLocation(uri: uri, location: function.location)]
                )
            }
        }
    }

    /// Mirrors the Xcode diagnostics severity convention for LCOM4.
    private func cohesionResults(for result: ComplexityResult) -> [SARIFResult] {
        guard let cohesions = result.classCohesions else { return [] }
        let uri = relativizedURI(for: result.filePath)

        return cohesions.compactMap { cohesion in
            guard !cohesion.isSuppressed(.lcom4), cohesion.cohesionLevel == .low else { return nil }
            let message =
                "\(cohesion.type.rawValue.capitalized) '\(cohesion.name)' has low cohesion (LCOM4: \(cohesion.lcom4))"
            return SARIFResult(
                ruleId: SARIFConstants.lcom4RuleId,
                level: cohesion.lcom4 >= 5 ? "error" : "warning",
                message: SARIFMessage(text: message),
                locations: [sarifLocation(uri: uri, location: cohesion.location)]
            )
        }
    }

    /// Coupling results exist only when coupling thresholds are configured,
    /// mirroring the exit-code gate: report-only runs upload no violations.
    private func couplingResults(
        for result: ComplexityResult, options: OutputOptions
    ) -> [SARIFResult] {
        guard let configuration = options.thresholdConfiguration,
            let couplings = result.typeCouplings
        else { return [] }
        let uri = relativizedURI(for: result.filePath)

        return couplings.flatMap { coupling -> [SARIFResult] in
            configuration.couplingViolations(coupling).map { violation in
                let (ruleId, label) =
                    violation.metric == .fanOut
                    ? (SARIFConstants.fanOutRuleId, "fan-out")
                    : (SARIFConstants.fanInRuleId, "fan-in")
                let message =
                    "\(coupling.kind.rawValue.capitalized) '\(coupling.name)' has \(label) \(violation.value) (threshold: \(violation.threshold))"
                return SARIFResult(
                    ruleId: ruleId,
                    level: violation.value >= violation.threshold * 2 ? "error" : "warning",
                    message: SARIFMessage(text: message),
                    locations: [sarifLocation(uri: uri, location: coupling.location)]
                )
            }
        }
    }

    private func sarifLocation(uri: String, location: SourceLocation) -> SARIFLocation {
        SARIFLocation(
            physicalLocation: SARIFPhysicalLocation(
                artifactLocation: SARIFArtifactLocation(uri: uri),
                region: SARIFRegion(startLine: location.line, startColumn: location.column)
            )
        )
    }

    /// GitHub Code Scanning expects URIs relative to the repository root, so
    /// absolute paths under the current working directory are relativized.
    private func relativizedURI(for filePath: String) -> String {
        let cwdPrefix = FileManager.default.currentDirectoryPath + "/"
        if filePath.hasPrefix(cwdPrefix) {
            return String(filePath.dropFirst(cwdPrefix.count))
        }
        if filePath.hasPrefix("./") {
            return String(filePath.dropFirst(2))
        }
        return filePath
    }
}
