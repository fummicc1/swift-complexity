import Foundation
import SwiftParser
import SwiftSyntax
import Testing

@testable import SwiftComplexityCore

// MARK: - Test Tags

extension Tag {
    @Tag static var unit: Self
    @Tag static var integration: Self
    @Tag static var performance: Self
    @Tag static var models: Self
    @Tag static var calculators: Self
    @Tag static var detectors: Self
    @Tag static var formatters: Self
}

// MARK: - Basic Model Tests

@Suite("Data Models", .tags(.unit, .models))
struct DataModelTests {

    @Test("SourceLocation basic functionality")
    func sourceLocationBasicFunctionality() {
        // Given
        let location = SourceLocation(line: 42, column: 10)

        // Then
        #expect(location.line == 42)
        #expect(location.column == 10)
        #expect(location.description == "42:10")
    }

    @Test("FunctionComplexity initialization")
    func functionComplexityInitialization() {
        // Given
        let location = SourceLocation(line: 1, column: 1)

        // When
        let function = FunctionComplexity(
            name: "testFunction",
            signature: "func testFunction() -> Void",
            cyclomaticComplexity: 3,
            cognitiveComplexity: 5,
            location: location
        )

        // Then
        #expect(function.name == "testFunction")
        #expect(function.cyclomaticComplexity == 3)
        #expect(function.cognitiveComplexity == 5)
        #expect(function.location.line == 1)
    }

    @Test("FileSummary with empty functions")
    func fileSummaryEmptyFunctions() {
        // When
        let summary = FileSummary(functions: [])

        // Then
        #expect(summary.totalFunctions == 0)
        #expect(summary.averageCyclomaticComplexity == 0.0)
        #expect(summary.averageCognitiveComplexity == 0.0)
        #expect(summary.maxCyclomaticComplexity == 0)
        #expect(summary.maxCognitiveComplexity == 0)
    }

    @Test("FileSummary with functions")
    func fileSummaryWithFunctions() {
        // Given
        let location = SourceLocation(line: 1, column: 1)
        let functions = [
            FunctionComplexity(
                name: "func1", signature: "func1()", cyclomaticComplexity: 2,
                cognitiveComplexity: 3, location: location),
            FunctionComplexity(
                name: "func2", signature: "func2()", cyclomaticComplexity: 4,
                cognitiveComplexity: 1, location: location),
            FunctionComplexity(
                name: "func3", signature: "func3()", cyclomaticComplexity: 1,
                cognitiveComplexity: 5, location: location),
        ]

        // When
        let summary = FileSummary(functions: functions)

        // Then
        #expect(summary.totalFunctions == 3)
        #expect(abs(summary.averageCyclomaticComplexity - 7.0 / 3.0) < 0.001)
        #expect(abs(summary.averageCognitiveComplexity - 9.0 / 3.0) < 0.001)
        #expect(summary.maxCyclomaticComplexity == 4)
        #expect(summary.maxCognitiveComplexity == 5)
        #expect(summary.totalCyclomaticComplexity == 7)
        #expect(summary.totalCognitiveComplexity == 9)
    }
}

// MARK: - Complexity Calculator Tests

@Suite("Complexity Calculators", .tags(.unit, .calculators))
struct ComplexityCalculatorTests {

    @Suite("Cyclomatic Complexity")
    struct CyclomaticComplexityTests {

        @Test("Simple function")
        func simpleFunction() throws {
            // Given
            let code = try loadFixture("simple_function")
            let sourceFile = Parser.parse(source: code)
            let calculator = CyclomaticComplexityCalculator(viewMode: .sourceAccurate)

            // When
            guard let function = sourceFile.statements.first?.item.as(FunctionDeclSyntax.self)
            else {
                Issue.record("Failed to parse function declaration")
                return
            }
            let complexity = calculator.calculate(for: function.body)

            // Then
            #expect(complexity == 1, "Simple function should have complexity 1")
        }

        @Test("Function with if")
        func functionWithIf() throws {
            // Given
            let code = try loadFixture("function_with_if")
            let sourceFile = Parser.parse(source: code)
            let calculator = CyclomaticComplexityCalculator(viewMode: .sourceAccurate)

            // When
            guard let function = sourceFile.statements.first?.item.as(FunctionDeclSyntax.self)
            else {
                Issue.record("Failed to parse function declaration")
                return
            }
            let complexity = calculator.calculate(for: function.body)

            // Then
            #expect(complexity == 2, "Function with if should have complexity 2")
        }

        @Test("Nested conditions")
        func nestedConditions() throws {
            // Given
            let code = try loadFixture("nested_conditions")
            let sourceFile = Parser.parse(source: code)
            let calculator = CyclomaticComplexityCalculator(viewMode: .sourceAccurate)

            // When
            guard let function = sourceFile.statements.first?.item.as(FunctionDeclSyntax.self)
            else {
                Issue.record("Failed to parse function declaration")
                return
            }
            let complexity = calculator.calculate(for: function.body)

            // Then
            // Expected: base(1) + if(1) + nested if(1) + else implied = 3
            #expect(complexity == 3, "Function with nested conditions should have complexity 3")
        }
    }

    @Suite("Cognitive Complexity")
    struct CognitiveComplexityTests {

        @Test("Simple function")
        func simpleFunction() throws {
            // Given
            let code = try loadFixture("simple_function")
            let sourceFile = Parser.parse(source: code)
            let calculator = CognitiveComplexityCalculator(viewMode: .sourceAccurate)

            // When
            guard let function = sourceFile.statements.first?.item.as(FunctionDeclSyntax.self)
            else {
                Issue.record("Failed to parse function declaration")
                return
            }
            let complexity = calculator.calculate(for: function.body)

            // Then
            #expect(complexity == 0, "Simple function should have cognitive complexity 0")
        }

        @Test("Nested conditions")
        func nestedConditions() throws {
            // Given
            let code = try loadFixture("cognitive_nested_conditions")
            let sourceFile = Parser.parse(source: code)
            let calculator = CognitiveComplexityCalculator(viewMode: .sourceAccurate)

            // When
            guard let function = sourceFile.statements.first?.item.as(FunctionDeclSyntax.self)
            else {
                Issue.record("Failed to parse function declaration")
                return
            }
            let complexity = calculator.calculate(for: function.body)

            // Then
            // Outer if: 1 + 0 (nesting) = 1
            // Inner if: 1 + 1 (nesting) = 2
            // Total: 3
            #expect(
                complexity == 3,
                "Function with nested conditions should have cognitive complexity 3")
        }

        @Test("Else-if chain (Issue #6)")
        func elseIfChain() throws {
            // Given
            let code = try loadFixture("else_if_chain")
            let sourceFile = Parser.parse(source: code)
            let calculator = CognitiveComplexityCalculator(viewMode: .sourceAccurate)

            // When
            guard let function = sourceFile.statements.first?.item.as(FunctionDeclSyntax.self)
            else {
                Issue.record("Failed to parse function declaration")
                return
            }
            let complexity = calculator.calculate(for: function.body)

            // Then
            // if value == 1: +1
            // else if value == 2: +1 (continuation, no nesting penalty)
            // else: +1 (no nesting penalty)
            // Total: 3
            #expect(
                complexity == 3,
                "Else-if chain should have cognitive complexity 3 (if +1, else if +1, else +1)"
            )
        }

        @Test("Deeply nested else-if chains (Issue #6)")
        func deeplyNestedElseIfChains() throws {
            // Given
            let code = try loadFixture("issue6_nested_else_if")
            let sourceFile = Parser.parse(source: code)
            let calculator = CognitiveComplexityCalculator(viewMode: .sourceAccurate)

            // When
            guard let function = sourceFile.statements.first?.item.as(FunctionDeclSyntax.self)
            else {
                Issue.record("Failed to parse function declaration")
                return
            }
            let complexity = calculator.calculate(for: function.body)

            // Then
            // This tests the fix for Issue #6:
            // https://github.com/fummicc1/swift-complexity/issues/6
            //
            // Breakdown (simplified):
            // - guard: +1
            // - if type == "user": +1
            // - nested if statements with increasing nesting penalties
            // - else if and else statements: +1 each (no nesting penalty)
            //
            // Expected: 46 (as documented in the issue)
            #expect(
                complexity == 46,
                "Deeply nested else-if chains should have cognitive complexity 46")
        }
    }
}

// MARK: - Function Detection Tests

@Suite("Function Detection", .tags(.unit, .detectors))
struct FunctionDetectionTests {

    @Test("Single function")
    func singleFunction() throws {
        // Given
        let code = try loadFixture("single_function")
        let sourceFile = Parser.parse(source: code)
        let detector = FunctionDetector(viewMode: .sourceAccurate)

        // When
        let functions = detector.detectFunctions(in: sourceFile)

        // Then
        #expect(functions.count == 1)
        #expect(functions[0].name == "testFunction")
        #expect(functions[0].signature.contains("testFunction(param: String)"))
    }

    @Test("Class with methods")
    func classWithMethods() throws {
        // Given
        let code = try loadFixture("class_with_methods")
        let sourceFile = Parser.parse(source: code)
        let detector = FunctionDetector(viewMode: .sourceAccurate)

        // When
        let functions = detector.detectFunctions(in: sourceFile)

        // Then
        #expect(functions.count == 3)

        let names = functions.map(\.name)
        #expect(names.contains("init"))
        #expect(names.contains("method1"))
        #expect(names.contains("method2"))
    }

    @Test("protocol")
    func protocolDeclTests() async throws {
        // Given
        let code = try loadFixture("protocol_decl")
        let sourceFile = Parser.parse(source: code)
        let detector = FunctionDetector(viewMode: .sourceAccurate)

        // When
        let functions = detector.detectFunctions(in: sourceFile)

        // Then
        #expect(functions.count == 0)
    }

    @Test("protocol_extension")
    func protocolExtensionDeclTests() async throws {
        // Given
        let code = try loadFixture("protocol_extension_decl")
        let sourceFile = Parser.parse(source: code)
        let detector = FunctionDetector(viewMode: .sourceAccurate)

        // When
        let functions = detector.detectFunctions(in: sourceFile)

        // Then
        #expect(functions.count == 1)
    }
}

// MARK: - Output Formatter Tests

@Suite("Output Formatting", .tags(.unit, .formatters))
struct OutputFormatterTests {

    @Test("Text format")
    func textFormat() {
        // Given
        let location = SourceLocation(line: 1, column: 1)
        let functions = [
            FunctionComplexity(
                name: "func1", signature: "func func1()", cyclomaticComplexity: 2,
                cognitiveComplexity: 3, location: location),
            FunctionComplexity(
                name: "func2", signature: "func func2()", cyclomaticComplexity: 1,
                cognitiveComplexity: 1, location: location),
        ]
        let result = ComplexityResult(filePath: "test.swift", functions: functions)
        let formatter = OutputFormatter()
        let options = OutputOptions()

        // When
        let output = formatter.format(results: [result], format: .text, options: options)

        // Then
        #expect(output.contains("File: test.swift"))
        #expect(output.contains("func1"))
        #expect(output.contains("func2"))
        #expect(output.contains("Total: 2 functions"))
    }

    @Test("JSON format")
    func jsonFormat() {
        // Given
        let location = SourceLocation(line: 1, column: 1)
        let functions = [
            FunctionComplexity(
                name: "testFunc", signature: "func testFunc()", cyclomaticComplexity: 1,
                cognitiveComplexity: 0, location: location)
        ]
        let result = ComplexityResult(filePath: "test.swift", functions: functions)
        let formatter = OutputFormatter()
        let options = OutputOptions()

        // When
        let output = formatter.format(results: [result], format: .json, options: options)

        // Then
        #expect(output.contains("\"files\""))
        #expect(output.contains("\"testFunc\""))
        #expect(output.contains("\"cyclomaticComplexity\":1"))
        #expect(output.contains("\"cognitiveComplexity\":0"))
    }
}

// MARK: - Integration Tests

@Suite("Integration Tests", .tags(.integration))
struct IntegrationTests {

    @Test("Complete analysis flow")
    func completeAnalysisFlow() async throws {
        // Given
        let code = try loadFixture("integration_test_sample")
        let sourceFile = Parser.parse(source: code)
        let analyzer = ComplexityAnalyzer()

        // When
        let result = try await analyzer.analyze(sourceFile: sourceFile, filePath: "test.swift")

        // Then
        #expect(result.filePath == "test.swift")
        #expect(result.functions.count == 2)

        let simpleFunc = result.functions.first { $0.name == "simpleFunction" }
        let complexFunc = result.functions.first { $0.name == "complexFunction" }

        #expect(simpleFunc?.cyclomaticComplexity == 1)
        #expect(simpleFunc?.cognitiveComplexity == 0)

        #expect(complexFunc?.cyclomaticComplexity == 3)
        #expect(complexFunc != nil)

        #expect(result.summary.totalFunctions == 2)
        #expect(result.summary.maxCyclomaticComplexity >= 3)
    }
}

// MARK: - Performance Tests

@Suite("Performance Tests", .tags(.performance))
struct PerformanceTests {

    @Test("Large file analysis", .timeLimit(.minutes(1)))
    func largeFileAnalysis() {
        // Given
        var code = ""
        for i in 1...100 {
            code += """
                func function\(i)(param: Int) -> Int {
                    if param > 0 {
                        return param * 2
                    } else {
                        return 0
                    }
                }

                """
        }

        let sourceFile = Parser.parse(source: code)
        let detector = FunctionDetector(viewMode: .sourceAccurate)

        // When & Then
        _ = detector.detectFunctions(in: sourceFile)
    }

    @Test("Complexity calculation", .timeLimit(.minutes(1)))
    func complexityCalculation() throws {
        // Given
        let code = try loadFixture("very_complex_function")

        let sourceFile = Parser.parse(source: code)
        let cyclomaticCalculator = CyclomaticComplexityCalculator(viewMode: .sourceAccurate)
        let cognitiveCalculator = CognitiveComplexityCalculator(viewMode: .sourceAccurate)

        guard let function = sourceFile.statements.first?.item.as(FunctionDeclSyntax.self) else {
            Issue.record("Failed to parse function")
            return
        }

        // When & Then
        _ = cyclomaticCalculator.calculate(for: function.body)
        _ = cognitiveCalculator.calculate(for: function.body)
    }
}

// MARK: - Test Utilities

/// Helper method to load fixture file content
private func loadFixture(_ filename: String) throws -> String {
    let testBundle = Bundle.module
    guard
        let url = testBundle.url(
            forResource: filename, withExtension: "swift", subdirectory: "Fixtures")
    else {
        throw TestError.fixtureNotFound(filename)
    }
    return try String(contentsOf: url)
}

/// Test-specific errors
private enum TestError: Error {
    case fixtureNotFound(String)
}

/// Helper method to parse a function and return its complexity
private func measureComplexity(
    in code: String,
    using calculator: CyclomaticComplexityCalculator
) -> Int? {
    let sourceFile = Parser.parse(source: code)
    guard let function = sourceFile.statements.first?.item.as(FunctionDeclSyntax.self) else {
        return nil
    }
    return calculator.calculate(for: function.body)
}

/// Helper method to create a mock function for testing
private func createMockFunction(
    name: String = "mockFunction",
    cyclomaticComplexity: Int = 1,
    cognitiveComplexity: Int = 0
) -> FunctionComplexity {
    return FunctionComplexity(
        name: name,
        signature: "func \(name)()",
        cyclomaticComplexity: cyclomaticComplexity,
        cognitiveComplexity: cognitiveComplexity,
        location: SourceLocation(line: 1, column: 1)
    )
}
