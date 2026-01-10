import Foundation

public struct OutputOptions {
    public let showCyclomaticOnly: Bool
    public let showCognitiveOnly: Bool
    public let showLCOM4: Bool
    public let threshold: Int?

    public init(
        showCyclomaticOnly: Bool = false,
        showCognitiveOnly: Bool = false,
        showLCOM4: Bool = false,
        threshold: Int? = nil
    ) {
        self.showCyclomaticOnly = showCyclomaticOnly
        self.showCognitiveOnly = showCognitiveOnly
        self.showLCOM4 = showLCOM4
        self.threshold = threshold
    }
}

public class OutputFormatter {
    public init() {}

    public func format(results: [ComplexityResult], format: OutputFormat, options: OutputOptions)
        -> String
    {
        switch format {
        case .text:
            return formatAsText(results: results, options: options)
        case .json:
            return formatAsJSON(results: results, options: options)
        case .xml:
            return formatAsXML(results: results, options: options)
        case .xcode:
            return formatAsXcodeDiagnostics(results: results, options: options)
        }
    }

    private func formatAsText(results: [ComplexityResult], options: OutputOptions) -> String {
        let sections = results.compactMap { result -> String? in
            guard !result.functions.isEmpty || result.classCohesions != nil else { return nil }

            var parts: [String] = ["File: \(result.filePath)"]

            if let complexitySection = formatComplexitySection(result: result, options: options) {
                parts.append(complexitySection)
            }

            if let cohesionSection = formatCohesionSection(result: result, options: options) {
                parts.append(cohesionSection)
            }

            return parts.joined(separator: "\n")
        }

        return sections.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 複雑度テーブルセクションをフォーマット
    private func formatComplexitySection(
        result: ComplexityResult,
        options: OutputOptions
    ) -> String? {
        guard !options.showLCOM4, !result.functions.isEmpty else { return nil }

        var output = formatTableHeader(options: options)
        output += formatTableSeparator(options: options)
        for function in result.functions {
            output += formatTableRow(function: function, options: options)
        }
        output += formatTableSeparator(options: options)
        output += formatSummary(summary: result.summary, options: options)
        return output
    }

    /// 凝集度テーブルセクションをフォーマット
    private func formatCohesionSection(
        result: ComplexityResult,
        options: OutputOptions
    ) -> String? {
        guard let classCohesions = result.classCohesions else { return nil }

        var output = formatCohesionTable(classCohesions: classCohesions)
        if let summary = result.cohesionSummary {
            output += formatCohesionSummary(summary: summary)
        }
        return output
    }

    private func formatTableHeader(options: OutputOptions) -> String {
        let functionColumn = "Function/Method".padding(toLength: 20, withPad: " ", startingAt: 0)

        if options.showCyclomaticOnly {
            return "| \(functionColumn) | Cyclomatic |\n"
        } else if options.showCognitiveOnly {
            return "| \(functionColumn) | Cognitive  |\n"
        } else {
            return "| \(functionColumn) | Cyclomatic | Cognitive  |\n"
        }
    }

    private func formatTableSeparator(options: OutputOptions) -> String {
        if options.showCyclomaticOnly || options.showCognitiveOnly {
            return "+----------------------+------------+\n"
        } else {
            return "+----------------------+------------+------------+\n"
        }
    }

    private func formatTableRow(function: FunctionComplexity, options: OutputOptions) -> String {
        let name = function.name.padding(toLength: 20, withPad: " ", startingAt: 0)

        if options.showCyclomaticOnly {
            let cyclomatic = String(function.cyclomaticComplexity).padding(
                toLength: 10, withPad: " ", startingAt: 0)
            return "| \(name) | \(cyclomatic) |\n"
        } else if options.showCognitiveOnly {
            let cognitive = String(function.cognitiveComplexity).padding(
                toLength: 10, withPad: " ", startingAt: 0)
            return "| \(name) | \(cognitive) |\n"
        } else {
            let cyclomatic = String(function.cyclomaticComplexity).padding(
                toLength: 10, withPad: " ", startingAt: 0)
            let cognitive = String(function.cognitiveComplexity).padding(
                toLength: 10, withPad: " ", startingAt: 0)
            return "| \(name) | \(cyclomatic) | \(cognitive) |\n"
        }
    }

    private func formatSummary(summary: FileSummary, options: OutputOptions) -> String {
        let total = "Total: \(summary.totalFunctions) functions"

        if options.showCyclomaticOnly {
            let avgCyclomatic = String(format: "%.1f", summary.averageCyclomaticComplexity)
            return "\(total), Average Cyclomatic: \(avgCyclomatic)\n"
        } else if options.showCognitiveOnly {
            let avgCognitive = String(format: "%.1f", summary.averageCognitiveComplexity)
            return "\(total), Average Cognitive: \(avgCognitive)\n"
        } else {
            let avgCyclomatic = String(format: "%.1f", summary.averageCyclomaticComplexity)
            let avgCognitive = String(format: "%.1f", summary.averageCognitiveComplexity)
            return
                "\(total), Average Cyclomatic: \(avgCyclomatic), Average Cognitive: \(avgCognitive)\n"
        }
    }

    // MARK: - LCOM4 Cohesion Formatting

    private func formatCohesionTable(classCohesions: [ClassCohesion]) -> String {
        var output = "Class Cohesion (LCOM4):\n"
        output += formatCohesionTableHeader()
        output += formatCohesionTableSeparator()

        for cohesion in classCohesions {
            output += formatCohesionTableRow(cohesion: cohesion)
        }

        output += formatCohesionTableSeparator()
        return output
    }

    private func formatCohesionTableHeader() -> String {
        let nameColumn = "Class/Struct".padding(toLength: 25, withPad: " ", startingAt: 0)
        return "| \(nameColumn) | Type   | LCOM4 | Methods | Properties | Cohesion   |\n"
    }

    private func formatCohesionTableSeparator() -> String {
        return
            "+---------------------------+--------+-------+---------+------------+------------+\n"
    }

    private func formatCohesionTableRow(cohesion: ClassCohesion) -> String {
        let name = cohesion.name.padding(toLength: 25, withPad: " ", startingAt: 0)
        let type = cohesion.type.rawValue.padding(toLength: 6, withPad: " ", startingAt: 0)
        let lcom4 = String(cohesion.lcom4).padding(toLength: 5, withPad: " ", startingAt: 0)
        let methods = String(cohesion.methodCount).padding(toLength: 7, withPad: " ", startingAt: 0)
        let properties = String(cohesion.propertyCount).padding(
            toLength: 10, withPad: " ", startingAt: 0)
        let cohesionLevel = cohesion.cohesionLevel.rawValue.padding(
            toLength: 10, withPad: " ", startingAt: 0)

        return "| \(name) | \(type) | \(lcom4) | \(methods) | \(properties) | \(cohesionLevel) |\n"
    }

    private func formatCohesionSummary(summary: CohesionSummary) -> String {
        let avgLCOM4 = String(format: "%.2f", summary.averageLCOM4)
        return
            "Total: \(summary.totalClasses) classes, Average LCOM4: \(avgLCOM4), Low cohesion: \(summary.classesWithLowCohesion)\n"
    }

    private func formatAsJSON(results: [ComplexityResult], options: OutputOptions) -> String {
        do {
            let jsonData = try JSONEncoder().encode(["files": results])
            return String(data: jsonData, encoding: .utf8) ?? "{}"
        } catch {
            return "{\"error\": \"Failed to encode JSON: \(error.localizedDescription)\"}"
        }
    }

    private func formatAsXML(results: [ComplexityResult], options: OutputOptions) -> String {
        var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        xml += "<complexity-report>\n"

        for result in results {
            xml += "  <file path=\"\(xmlEscape(result.filePath))\">\n"

            // Function complexity
            if !result.functions.isEmpty {
                for function in result.functions {
                    xml += "    <function name=\"\(xmlEscape(function.name))\" "
                    xml += "signature=\"\(xmlEscape(function.signature))\" "
                    xml += "line=\"\(function.location.line)\" "
                    xml += "column=\"\(function.location.column)\">\n"
                    xml +=
                        "      <cyclomatic-complexity>\(function.cyclomaticComplexity)</cyclomatic-complexity>\n"
                    xml +=
                        "      <cognitive-complexity>\(function.cognitiveComplexity)</cognitive-complexity>\n"
                    xml += "    </function>\n"
                }

                xml += "    <summary>\n"
                xml += "      <total-functions>\(result.summary.totalFunctions)</total-functions>\n"
                xml +=
                    "      <average-cyclomatic-complexity>\(result.summary.averageCyclomaticComplexity)</average-cyclomatic-complexity>\n"
                xml +=
                    "      <average-cognitive-complexity>\(result.summary.averageCognitiveComplexity)</average-cognitive-complexity>\n"
                xml +=
                    "      <max-cyclomatic-complexity>\(result.summary.maxCyclomaticComplexity)</max-cyclomatic-complexity>\n"
                xml +=
                    "      <max-cognitive-complexity>\(result.summary.maxCognitiveComplexity)</max-cognitive-complexity>\n"
                xml += "    </summary>\n"
            }

            // Class cohesion (LCOM4)
            if let classCohesions = result.classCohesions {
                for cohesion in classCohesions {
                    xml += "    <class name=\"\(xmlEscape(cohesion.name))\" "
                    xml += "type=\"\(cohesion.type.rawValue)\" "
                    xml += "line=\"\(cohesion.location.line)\" "
                    xml += "column=\"\(cohesion.location.column)\">\n"
                    xml += "      <lcom4>\(cohesion.lcom4)</lcom4>\n"
                    xml += "      <method-count>\(cohesion.methodCount)</method-count>\n"
                    xml += "      <property-count>\(cohesion.propertyCount)</property-count>\n"
                    xml +=
                        "      <cohesion-level>\(cohesion.cohesionLevel.rawValue)</cohesion-level>\n"
                    xml += "    </class>\n"
                }

                if let cohesionSummary = result.cohesionSummary {
                    xml += "    <cohesion-summary>\n"
                    xml += "      <total-classes>\(cohesionSummary.totalClasses)</total-classes>\n"
                    xml +=
                        "      <average-lcom4>\(cohesionSummary.averageLCOM4)</average-lcom4>\n"
                    xml += "      <max-lcom4>\(cohesionSummary.maxLCOM4)</max-lcom4>\n"
                    xml +=
                        "      <low-cohesion-classes>\(cohesionSummary.classesWithLowCohesion)</low-cohesion-classes>\n"
                    xml += "    </cohesion-summary>\n"
                }
            }

            xml += "  </file>\n"
        }

        xml += "</complexity-report>\n"
        return xml
    }

    private func xmlEscape(_ string: String) -> String {
        return
            string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }

    // MARK: - Xcode Diagnostics Format

    private func formatAsXcodeDiagnostics(results: [ComplexityResult], options: OutputOptions)
        -> String
    {
        let threshold = options.threshold ?? 10

        let complexityDiagnostics = results.flatMap { result in
            result.functions.compactMap { function in
                createComplexityDiagnostic(for: function, in: result.filePath, threshold: threshold)
            }
        }

        let cohesionDiagnostics = results.flatMap { result in
            (result.classCohesions ?? []).compactMap { cohesion in
                createCohesionDiagnostic(for: cohesion, in: result.filePath)
            }
        }

        let allDiagnostics = complexityDiagnostics + cohesionDiagnostics
        return allDiagnostics.isEmpty ? "" : allDiagnostics.joined(separator: "\n") + "\n"
    }

    /// 複雑度診断メッセージを作成
    private func createComplexityDiagnostic(
        for function: FunctionComplexity,
        in filePath: String,
        threshold: Int
    ) -> String? {
        let cyclomatic = function.cyclomaticComplexity
        let cognitive = function.cognitiveComplexity

        guard cyclomatic > threshold || cognitive > threshold else { return nil }

        let severity =
            (cyclomatic > threshold * 2 || cognitive > threshold * 2) ? "error" : "warning"
        let message =
            "Function '\(function.name)' has high complexity (Cyclomatic: \(cyclomatic), Cognitive: \(cognitive), Threshold: \(threshold))"

        return
            "\(filePath):\(function.location.line):\(function.location.column): \(severity): \(message)"
    }

    /// 凝集度診断メッセージを作成
    private func createCohesionDiagnostic(
        for cohesion: ClassCohesion,
        in filePath: String
    ) -> String? {
        guard cohesion.cohesionLevel == .low else { return nil }

        let severity = cohesion.lcom4 >= 5 ? "error" : "warning"
        let message =
            "\(cohesion.type.rawValue.capitalized) '\(cohesion.name)' has low cohesion (LCOM4: \(cohesion.lcom4), Level: \(cohesion.cohesionLevel.rawValue))"

        return
            "\(filePath):\(cohesion.location.line):\(cohesion.location.column): \(severity): \(message)"
    }
}
