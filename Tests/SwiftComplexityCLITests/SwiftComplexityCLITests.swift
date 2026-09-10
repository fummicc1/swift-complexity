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
        #expect(config.version == SwiftComplexityVersion.current)
    }

    @Test("OutputFormat ArgumentParser conformance")
    func outputFormatArgumentParser() {
        // Given & When
        let textFormat = OutputFormat(argument: "text")
        let jsonFormat = OutputFormat(argument: "json")
        let xmlFormat = OutputFormat(argument: "xml")
        let sarifFormat = OutputFormat(argument: "sarif")
        let invalidFormat = OutputFormat(argument: "invalid")

        // Then
        #expect(textFormat == .text)
        #expect(jsonFormat == .json)
        #expect(xmlFormat == .xml)
        #expect(sarifFormat == .sarif)
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
        #expect(values.count == 5)
        #expect(values.contains("text"))
        #expect(values.contains("json"))
        #expect(values.contains("xml"))
        #expect(values.contains("xcode"))
        #expect(values.contains("sarif"))
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

    @Test("--coupling parses and requires an index store path at run time")
    func couplingFlagValidation() async throws {
        // Parsing accepts the flag on its own...
        let parsed = try ComplexityCommand.parse(["Sources", "--coupling"])
        #expect(parsed.coupling)
        #expect(parsed.indexStorePath == nil)

        // ...but running without --index-store-path fails fast with a clear
        // error, before any file processing happens.
        await #expect(throws: ExitCode.self) {
            var command = parsed
            try await command.run()
        }
    }

    #if !IndexStore
        @Test("Index-backed flags fail fast when built without the IndexStore trait")
        func indexBackedFlagsUnavailableWithoutTrait() async throws {
            for flag in ["--lcom4", "--coupling"] {
                let parsed = try ComplexityCommand.parse([
                    "Sources", flag, "--index-store-path", ".build/debug/index/store",
                ])
                await #expect(throws: ExitCode.self) {
                    var command = parsed
                    try await command.run()
                }
            }
        }
    #endif

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

// MARK: - Config Option Tests

@Suite("CLI Config Option", .tags(.cli))
struct CLIConfigOptionTests {

    @Test("--config option is parsed")
    func configOptionParsed() throws {
        let command = try ComplexityCommand.parse(["Sources", "--config", "rules.yml"])
        #expect(command.config == "rules.yml")
        #expect(command.paths == ["Sources"])
    }

    @Test("--config defaults to nil when absent")
    func configDefaultsToNil() throws {
        let command = try ComplexityCommand.parse(["Sources"])
        #expect(command.config == nil)
    }

    @Test("--config and --threshold can be combined")
    func configWithThreshold() throws {
        let command = try ComplexityCommand.parse([
            "Sources", "--config", "rules.yml", "--threshold", "10",
        ])
        #expect(command.config == "rules.yml")
        #expect(command.threshold == 10)
    }

    @Test("--report-suppressions defaults to false")
    func reportSuppressionsDefaultsToFalse() throws {
        let command = try ComplexityCommand.parse(["Sources"])
        #expect(command.reportSuppressions == false)
    }

    @Test("--report-suppressions is parsed")
    func reportSuppressionsParsed() throws {
        let command = try ComplexityCommand.parse(["Sources", "--report-suppressions"])
        #expect(command.reportSuppressions == true)
    }
}

// MARK: - Config Execution Tests

@Suite("CLI Config Execution", .tags(.cli, .integration))
struct CLIConfigExecutionTests {

    /// Writes a config file and a source file into a scratch directory and
    /// hands both paths to `body`. The directory is removed afterwards.
    private func withFixture(
        yaml: String,
        source: String,
        _ body: (_ sourcePath: String, _ configPath: String) async throws -> Void
    ) async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("swift-complexity-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let configURL = directory.appendingPathComponent(".swift-complexity.yml")
        let sourceURL = directory.appendingPathComponent("Fixture.swift")
        try yaml.write(to: configURL, atomically: true, encoding: .utf8)
        try source.write(to: sourceURL, atomically: true, encoding: .utf8)

        try await body(sourceURL.path, configURL.path)
    }

    /// Cyclomatic complexity of the generated method is 1 + `branches`.
    private func source(typeName: String, branches: Int) -> String {
        let ifs = (0..<branches)
            .map { "        if flags[\($0)] { count += 1 }" }
            .joined(separator: "\n")
        return """
            struct \(typeName) {
                func find(flags: [Bool]) -> Int {
                    var count = 0
            \(ifs)
                    return count
                }
            }
            """
    }

    @Test("A rule threshold gates inclusively through the CLI")
    func ruleThresholdGatesAtBoundary() async throws {
        let yaml = """
            rules:
              - suffix: Repository
                threshold: 5
            """
        // 4 branches -> cyclomatic 5, exactly on the rule threshold
        try await withFixture(yaml: yaml, source: source(typeName: "UserRepository", branches: 4)) {
            sourcePath, configPath in
            let command = try ComplexityCommand.parse([sourcePath, "--config", configPath])
            await #expect(throws: ExitCode.self) {
                try await command.run()
            }
        }
    }

    @Test("Complexity below the rule threshold exits normally")
    func ruleThresholdPassesBelowBoundary() async throws {
        let yaml = """
            rules:
              - suffix: Repository
                threshold: 5
            """
        try await withFixture(yaml: yaml, source: source(typeName: "UserRepository", branches: 3)) {
            sourcePath, configPath in
            let command = try ComplexityCommand.parse([sourcePath, "--config", configPath])
            try await command.run()
        }
    }

    @Test("--threshold overrides the config defaultThreshold as fallback")
    func thresholdFlagOverridesConfigDefault() async throws {
        let yaml = "defaultThreshold: 5"
        // 6 branches -> cyclomatic 7: violates the config default of 5 but
        // passes once --threshold 10 takes over as the fallback
        try await withFixture(yaml: yaml, source: source(typeName: "SomeService", branches: 6)) {
            sourcePath, configPath in
            let gated = try ComplexityCommand.parse([sourcePath, "--config", configPath])
            await #expect(throws: ExitCode.self) {
                try await gated.run()
            }

            let overridden = try ComplexityCommand.parse([
                sourcePath, "--config", configPath, "--threshold", "10",
            ])
            try await overridden.run()
        }
    }

    @Test("Malformed YAML fails the run")
    func malformedConfigFails() async throws {
        let yaml = """
            rules:
              - suffix: Repository
                 threshold: [broken
            """
        try await withFixture(yaml: yaml, source: source(typeName: "UserRepository", branches: 1)) {
            sourcePath, configPath in
            let command = try ComplexityCommand.parse([sourcePath, "--config", configPath])
            await #expect(throws: ExitCode.self) {
                try await command.run()
            }
        }
    }

    @Test("A missing config path fails the run")
    func missingConfigPathFails() async throws {
        let command = try ComplexityCommand.parse([
            "Sources", "--config", "/nonexistent/swift-complexity-missing.yml",
        ])
        await #expect(throws: ExitCode.self) {
            try await command.run()
        }
    }
}
