import Foundation

public struct OutputOptions {
  public let showCyclomaticOnly: Bool
  public let showCognitiveOnly: Bool
  public let threshold: Int?

  public init(
    showCyclomaticOnly: Bool = false, showCognitiveOnly: Bool = false, threshold: Int? = nil
  ) {
    self.showCyclomaticOnly = showCyclomaticOnly
    self.showCognitiveOnly = showCognitiveOnly
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
    }
  }

  private func formatAsText(results: [ComplexityResult], options: OutputOptions) -> String {
    var output = ""

    for result in results {
      if result.functions.isEmpty {
        continue
      }

      output += "File: \(result.filePath)\n"
      output += formatTableHeader(options: options)
      output += formatTableSeparator(options: options)

      for function in result.functions {
        output += formatTableRow(function: function, options: options)
      }

      output += formatTableSeparator(options: options)
      output += formatSummary(summary: result.summary, options: options)
      output += "\n"
    }

    return output.trimmingCharacters(in: .whitespacesAndNewlines)
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
}
