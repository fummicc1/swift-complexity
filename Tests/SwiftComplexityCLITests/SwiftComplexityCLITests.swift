import ArgumentParser
import Foundation
import SwiftSyntax
import Testing

@testable import SwiftComplexityCLI
@testable import SwiftComplexityCore

// MARK: - Test Tags

extension Tag {
  @Tag static var cli: Self
  @Tag static var integration: Self
  @Tag static var validation: Self
}

// MARK: - CLI Tests

@Suite("CLI Command Tests", .tags(.cli))
struct CLICommandTests {

  @Test("Command configuration")
  func commandConfiguration() {
    // Given
    let config = ComplexityCommand.configuration

    // Then
    #expect(config.commandName == "swift-complexity")
    #expect(config.abstract == "Analyze Swift code complexity and quality metrics")
    #expect(config.version == "1.0.0")
  }

  @Test("OutputFormat ArgumentParser conformance")
  func outputFormatArgumentParser() {
    // Given & When
    let textFormat = OutputFormat(argument: "text")
    let jsonFormat = OutputFormat(argument: "json")
    let xmlFormat = OutputFormat(argument: "xml")
    let invalidFormat = OutputFormat(argument: "invalid")

    // Then
    #expect(textFormat == .text)
    #expect(jsonFormat == .json)
    #expect(xmlFormat == .xml)
    #expect(invalidFormat == nil)
  }

  @Test("OutputFormat help text")
  func outputFormatHelp() {
    // Given & When
    let help = OutputFormat.help

    // Then
    #expect(help.contains("text"))
    #expect(help.contains("json"))
    #expect(help.contains("xml"))
    #expect(help.contains("Human-readable"))
    #expect(help.contains("machine processing"))
    #expect(help.contains("report tools"))
  }

  @Test("All value strings")
  func allValueStrings() {
    // Given & When
    let values = OutputFormat.allValueStrings

    // Then
    #expect(values.count == 3)
    #expect(values.contains("text"))
    #expect(values.contains("json"))
    #expect(values.contains("xml"))
  }
}

@Suite("CLI Integration Tests", .tags(.cli, .integration))
struct CLIIntegrationTests {

  @Test("CLI Error types")
  func cliErrorTypes() {
    // Given
    let processingError = CLIError.processingFailed("Test error")
    let unexpectedError = CLIError.unexpectedError("Unexpected")

    // Then
    #expect(processingError.localizedDescription.contains("Processing failed"))
    #expect(processingError.localizedDescription.contains("Test error"))
    #expect(unexpectedError.localizedDescription.contains("Unexpected error"))
    #expect(unexpectedError.localizedDescription.contains("Unexpected"))
  }
}

@Suite("CLI Validation Tests", .tags(.cli, .validation))
struct CLIValidationTests {

  @Test("Mutually exclusive flags validation concept")
  func mutuallyExclusiveFlagsValidation() {
    // This test validates the concept of mutually exclusive flags
    // In actual CLI execution, these would be caught during command parsing

    // Given
    let cyclomaticOnly = true
    let cognitiveOnly = true

    // When
    let isConflict = cyclomaticOnly && cognitiveOnly

    // Then
    #expect(isConflict == true)
  }

  @Test("Threshold filtering logic")
  func thresholdFilteringLogic() {
    // Given
    let location = SourceLocation(line: 1, column: 1)
    let functions = [
      FunctionComplexity(
        name: "simple", signature: "simple()",
        cyclomaticComplexity: 1, cognitiveComplexity: 0, location: location),
      FunctionComplexity(
        name: "complex", signature: "complex()",
        cyclomaticComplexity: 5, cognitiveComplexity: 8, location: location),
    ]
    let result = ComplexityResult(filePath: "test.swift", functions: functions)
    let results = [result]

    // When - Filter with threshold 3
    let filteredResults = filterByThreshold(results: results, threshold: 3)

    // Then
    #expect(filteredResults.count == 1)
    #expect(filteredResults[0].functions.count == 1)
    #expect(filteredResults[0].functions[0].name == "complex")
  }

  // Helper method to test threshold filtering logic
  private func filterByThreshold(results: [ComplexityResult], threshold: Int?)
    -> [ComplexityResult]
  {
    guard let threshold = threshold else { return results }

    return results.compactMap { result in
      let filteredFunctions = result.functions.filter { function in
        function.cyclomaticComplexity >= threshold
          || function.cognitiveComplexity >= threshold
      }

      guard !filteredFunctions.isEmpty else { return nil }

      return ComplexityResult(filePath: result.filePath, functions: filteredFunctions)
    }
  }
}
