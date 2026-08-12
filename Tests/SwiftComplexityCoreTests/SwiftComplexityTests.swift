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

    @Test("NominalType coupling-only cases round-trip and keep raw values")
    func nominalTypeCouplingCases() throws {
        // enum/protocol exist for coupling metrics; LCOM4 must never emit them.
        #expect(NominalType.enum.rawValue == "enum")
        #expect(NominalType.protocol.rawValue == "protocol")
        for kind in [NominalType.enum, .protocol] {
            let data = try JSONEncoder().encode(kind)
            #expect(try JSONDecoder().decode(NominalType.self, from: data) == kind)
        }
    }

    @Test("TypeCoupling derives instability from the counts")
    func typeCouplingInstability() {
        let location = SourceLocation(line: 1, column: 1)
        // 2 / (1 + 2) = 0.666..., and isolated types have no defined ratio.
        let coupled = TypeCoupling(
            name: "A", kind: .struct, fanIn: 1, fanOut: 2, location: location)
        #expect(coupled.instability != nil)
        #expect(abs(coupled.instability! - 2.0 / 3.0) < 0.0001)
        let entryPoint = TypeCoupling(
            name: "B", kind: .class, fanIn: 0, fanOut: 5, location: location)
        #expect(entryPoint.instability == 1.0)
        let isolated = TypeCoupling(
            name: "C", kind: .enum, fanIn: 0, fanOut: 0, location: location)
        #expect(isolated.instability == nil)
    }

    @Test("TypeCoupling round-trips through Codable, nil instability omits the key")
    func typeCouplingCodable() throws {
        let coupling = TypeCoupling(
            name: "Isolated", kind: .protocol, fanIn: 0, fanOut: 0,
            location: SourceLocation(line: 3, column: 1),
            suppressedMetrics: [.coupling])
        let data = try JSONEncoder().encode(coupling)
        let decoded = try JSONDecoder().decode(TypeCoupling.self, from: data)
        #expect(decoded == coupling)
        // Optionals encode via encodeIfPresent: an absent key keeps the JSON
        // schema additive for consumers that reject unknown null values.
        let json = String(decoding: data, as: UTF8.self)
        #expect(!json.contains("instability"))
    }

    @Test("CouplingSummary aggregates and stays safe on empty input")
    func couplingSummaryAggregation() {
        let location = SourceLocation(line: 1, column: 1)
        let types = [
            TypeCoupling(name: "A", kind: .struct, fanIn: 4, fanOut: 1, location: location),
            TypeCoupling(name: "B", kind: .class, fanIn: 0, fanOut: 7, location: location),
        ]
        let summary = CouplingSummary(types: types)
        #expect(summary.totalTypes == 2)
        #expect(summary.maxFanIn == 4)
        #expect(summary.maxFanOut == 7)
        #expect(abs(summary.averageFanOut - 4.0) < 0.0001)
        let empty = CouplingSummary(types: [])
        #expect(empty.totalTypes == 0)
        #expect(empty.averageFanOut == 0.0)
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

    @Test("Computed property detection")
    func computedPropertyDetection() throws {
        // Given
        let code = try loadFixture("computed_property")
        let sourceFile = Parser.parse(source: code)
        let detector = FunctionDetector(viewMode: .sourceAccurate)

        // When
        let functions = detector.detectFunctions(in: sourceFile)
        let names = functions.map(\.name)

        // Then
        // shorthandGetter: 1 (shorthand computed property)
        // explicitProperty.get: 1 (explicit get accessor)
        // explicitProperty.set: 1 (explicit set accessor)
        // observedProperty.didSet: 1 (property observer)
        // Total: 4 detected functions/accessors
        #expect(functions.count == 4)

        // Verify shorthand computed property is detected with property name
        #expect(names.contains("shorthandGetter"))

        // Verify explicit accessors include property name
        #expect(names.contains("explicitProperty.get"))
        #expect(names.contains("explicitProperty.set"))

        // Verify property observers include property name
        #expect(names.contains("observedProperty.didSet"))
    }

    @Test("Shorthand computed property complexity")
    func shorthandComputedPropertyComplexity() async throws {
        // Given
        let code = try loadFixture("computed_property")
        let sourceFile = Parser.parse(source: code)
        let analyzer = try ComplexityAnalyzer()

        // When
        let result = try await analyzer.analyze(sourceFile: sourceFile, filePath: "test.swift")

        // Then - verify shorthandGetter complexity
        let shorthandGetter = result.functions.first { $0.name == "shorthandGetter" }
        #expect(shorthandGetter != nil, "shorthandGetter should be detected")
        // Expected: cyclomatic = 3 (base 1 + 2 if statements)
        // Expected: cognitive = 3 (2 if statements + 1 else)
        #expect(shorthandGetter?.cyclomaticComplexity == 3)
        #expect(shorthandGetter?.cognitiveComplexity == 3)
    }

    @Test("Explicit accessor complexity")
    func explicitAccessorComplexity() async throws {
        // Given
        let code = try loadFixture("computed_property")
        let sourceFile = Parser.parse(source: code)
        let analyzer = try ComplexityAnalyzer()

        // When
        let result = try await analyzer.analyze(sourceFile: sourceFile, filePath: "test.swift")

        // Then - verify explicitProperty.get complexity
        let getter = result.functions.first { $0.name == "explicitProperty.get" }
        #expect(getter != nil, "explicitProperty.get should be detected")
        // Expected: cyclomatic = 2 (base 1 + 1 if statement)
        // Expected: cognitive = 1 (1 if statement)
        #expect(getter?.cyclomaticComplexity == 2)
        #expect(getter?.cognitiveComplexity == 1)

        // Then - verify explicitProperty.set complexity
        let setter = result.functions.first { $0.name == "explicitProperty.set" }
        #expect(setter != nil, "explicitProperty.set should be detected")
        // Expected: cyclomatic = 1 (base only)
        // Expected: cognitive = 0 (no control flow)
        #expect(setter?.cyclomaticComplexity == 1)
        #expect(setter?.cognitiveComplexity == 0)
    }

    @Test("Suppression comments are scoped to their own declaration")
    func suppressionCommentsScoping() async throws {
        // Given
        let code = try loadFixture("suppressed_functions")
        let sourceFile = Parser.parse(source: code)
        let analyzer = try ComplexityAnalyzer()

        // When
        let result = try await analyzer.analyze(sourceFile: sourceFile, filePath: "test.swift")
        func suppressed(_ name: String) -> Set<SuppressedMetric>? {
            result.functions.first { $0.name == name }?.suppressedMetrics
        }

        // Then
        // Bare disable on a function yields only function-level metrics —
        // lcom4 must never leak into a function's suppression set.
        #expect(suppressed("fullySuppressed") == SuppressedMetric.functionLevel)
        #expect(suppressed("cyclomaticOnlySuppressed") == [.cyclomatic])
        #expect(suppressed("cognitiveOnlySuppressed") == [.cognitive])
        // An unrelated preceding comment must not trigger suppression.
        #expect(suppressed("notSuppressed") == nil)
        // A typo'd metric name fails closed: nothing is suppressed.
        #expect(suppressed("typoedMetricNotSuppressed") == nil)
        // Suppression scopes to a computed property's own declaration too.
        #expect(suppressed("isValid") == SuppressedMetric.functionLevel)
    }
}

// MARK: - Suppression Parsing Tests

@Suite("Suppression parsing", .tags(.unit, .detectors))
struct SuppressionParserTests {

    @Test("Bare disable suppresses every metric applicable to the declaration")
    func bareDisable() {
        let trivia: Trivia = [.lineComment("// swift-complexity:disable"), .newlines(1)]
        #expect(
            SuppressionParser.suppressedMetrics(
                in: trivia, applicableTo: SuppressedMetric.functionLevel)
                == SuppressedMetric.functionLevel)
        #expect(
            SuppressionParser.suppressedMetrics(
                in: trivia, applicableTo: SuppressedMetric.typeLevel)
                == SuppressedMetric.typeLevel)
    }

    @Test("Specific metric name suppresses only that metric")
    func specificMetric() {
        let trivia: Trivia = [
            .lineComment("// swift-complexity:disable cyclomatic"), .newlines(1),
        ]
        #expect(
            SuppressionParser.suppressedMetrics(
                in: trivia, applicableTo: SuppressedMetric.functionLevel) == [.cyclomatic])
    }

    @Test("Comma-separated metric names are all recognized")
    func commaSeparatedMetrics() {
        let trivia: Trivia = [
            .lineComment("// swift-complexity:disable cyclomatic, cognitive"), .newlines(1),
        ]
        #expect(
            SuppressionParser.suppressedMetrics(
                in: trivia, applicableTo: SuppressedMetric.functionLevel)
                == [.cyclomatic, .cognitive])
    }

    @Test("Unrecognized metric name suppresses nothing (fails closed on a typo)")
    func typoedMetricSuppressesNothing() {
        let trivia: Trivia = [
            .lineComment("// swift-complexity:disable cyclomattic"), .newlines(1),
        ]
        #expect(
            SuppressionParser.suppressedMetrics(
                in: trivia, applicableTo: SuppressedMetric.functionLevel
            ).isEmpty)
    }

    @Test("Metric of the wrong declaration level suppresses nothing")
    func wrongLevelMetricSuppressesNothing() {
        // lcom4 above a function-level declaration
        let lcom4Trivia: Trivia = [
            .lineComment("// swift-complexity:disable lcom4"), .newlines(1),
        ]
        #expect(
            SuppressionParser.suppressedMetrics(
                in: lcom4Trivia, applicableTo: SuppressedMetric.functionLevel
            ).isEmpty)

        // cyclomatic above a type declaration
        let cyclomaticTrivia: Trivia = [
            .lineComment("// swift-complexity:disable cyclomatic"), .newlines(1),
        ]
        #expect(
            SuppressionParser.suppressedMetrics(
                in: cyclomaticTrivia, applicableTo: SuppressedMetric.typeLevel
            ).isEmpty)
    }

    @Test("lcom4 token is recognized for type declarations")
    func lcom4Token() {
        let trivia: Trivia = [.lineComment("// swift-complexity:disable lcom4"), .newlines(1)]
        #expect(
            SuppressionParser.suppressedMetrics(
                in: trivia, applicableTo: SuppressedMetric.typeLevel) == [.lcom4])
    }

    @Test("coupling token is recognized for type declarations")
    func couplingToken() {
        let trivia: Trivia = [.lineComment("// swift-complexity:disable coupling"), .newlines(1)]
        #expect(
            SuppressionParser.suppressedMetrics(
                in: trivia, applicableTo: SuppressedMetric.typeLevel) == [.coupling])
        // coupling above a function-level declaration suppresses nothing.
        #expect(
            SuppressionParser.suppressedMetrics(
                in: trivia, applicableTo: SuppressedMetric.functionLevel
            ).isEmpty)
    }

    @Test("coupling scope narrowed to enum/protocol excludes lcom4 from bare disable")
    func couplingOnlyScope() {
        // enum/protocol declarations pass [.coupling] as the applicable set,
        // so a bare disable must not leak lcom4 into their suppression set.
        let trivia: Trivia = [.lineComment("// swift-complexity:disable"), .newlines(1)]
        #expect(
            SuppressionParser.suppressedMetrics(
                in: trivia, applicableTo: [.coupling]) == [.coupling])
    }

    @Test("SuppressedMetric.coupling model invariants")
    func couplingMetricInvariants() throws {
        #expect(SuppressedMetric.coupling.rawValue == "coupling")
        #expect(SuppressedMetric.typeLevel == [.lcom4, .coupling])
        // The function-level set must stay unchanged by the coupling addition.
        #expect(SuppressedMetric.functionLevel == [.cyclomatic, .cognitive])
        let data = try JSONEncoder().encode(SuppressedMetric.coupling)
        #expect(try JSONDecoder().decode(SuppressedMetric.self, from: data) == .coupling)
    }

    @Test("Unrelated comment is not treated as a directive")
    func unrelatedCommentIgnored() {
        let trivia: Trivia = [.lineComment("// just a regular comment"), .newlines(1)]
        #expect(
            SuppressionParser.suppressedMetrics(
                in: trivia, applicableTo: SuppressedMetric.functionLevel
            ).isEmpty)
    }

    @Test("Doc comments are never treated as a directive")
    func docCommentIgnored() {
        let trivia: Trivia = [.docLineComment("/// swift-complexity:disable"), .newlines(1)]
        #expect(
            SuppressionParser.suppressedMetrics(
                in: trivia, applicableTo: SuppressedMetric.functionLevel
            ).isEmpty)
    }

    @Test("A false-prefix match like disableFoo is not our directive")
    func falsePrefixNotMatched() {
        let trivia: Trivia = [.lineComment("// swift-complexity:disableFoo"), .newlines(1)]
        #expect(
            SuppressionParser.suppressedMetrics(
                in: trivia, applicableTo: SuppressedMetric.functionLevel
            ).isEmpty)
    }
}

// MARK: - Nominal Type Detection Tests

@Suite("Nominal type detection", .tags(.unit, .detectors))
struct NominalTypeDetectorTests {

    @Test("Type-level suppression comments are scoped to their own declaration")
    func typeSuppressionScoping() throws {
        // Given
        let code = try loadFixture("suppressed_types")
        let sourceFile = Parser.parse(source: code)
        let detector = NominalTypeDetector(viewMode: .sourceAccurate)

        // When
        let types = detector.detectTypes(in: sourceFile)
        func suppressed(_ name: String) -> Set<SuppressedMetric>? {
            types.first { $0.name == name }?.suppressedMetrics
        }

        // Then
        #expect(types.count == 5)
        // A bare disable above a type suppresses only the type's own metrics,
        // never its member functions. NominalTypeDetector reports lcom4 only —
        // ClassCohesion output must not change when new type-level metrics
        // (e.g. coupling) are added; those are collected separately.
        #expect(suppressed("BareSuppressedClass") == [.lcom4])
        #expect(suppressed("Lcom4SuppressedStruct") == [.lcom4])
        #expect(suppressed("NotSuppressedActor") == [])
        // A function-level metric name above a type fails closed.
        #expect(suppressed("WrongLevelMetricClass") == [])
        #expect(suppressed("TypoedMetricClass") == [])
    }

    @Test("Member functions of a bare-suppressed type stay checked")
    func noCascadeToMemberFunctions() throws {
        // Given
        let code = try loadFixture("suppressed_types")
        let sourceFile = Parser.parse(source: code)
        let detector = FunctionDetector(viewMode: .sourceAccurate)

        // When
        let functions = detector.detectFunctions(in: sourceFile)

        // Then - no function inherits suppression from its enclosing type
        for function in functions {
            #expect(
                function.suppressedMetrics.isEmpty,
                "\(function.name) must not inherit type-level suppression")
        }
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

    @Test("Xcode diagnostics still flag a function via its non-suppressed metric")
    func xcodeDiagnosticsPartiallySuppressed() {
        // Given - both metrics exceed the threshold, but only cyclomatic is suppressed
        let functions = [
            FunctionComplexity(
                name: "partiallySuppressed", signature: "func partiallySuppressed()",
                cyclomaticComplexity: 20, cognitiveComplexity: 20,
                location: SourceLocation(line: 3, column: 1),
                suppressedMetrics: [.cyclomatic])
        ]
        let result = ComplexityResult(filePath: "test.swift", functions: functions)
        let formatter = OutputFormatter()
        let options = OutputOptions(threshold: 10)

        // When
        let output = formatter.format(results: [result], format: .xcode, options: options)

        // Then - still reported (cognitive is not suppressed), values remain visible
        #expect(output.contains("test.swift:3:1"))
        #expect(output.contains("Cyclomatic: 20, Cognitive: 20"))
    }

    @Test("Xcode diagnostics stay silent when every offending metric is suppressed")
    func xcodeDiagnosticsFullySuppressed() {
        // Given
        let functions = [
            FunctionComplexity(
                name: "fullySuppressed", signature: "func fullySuppressed()",
                cyclomaticComplexity: 20, cognitiveComplexity: 20,
                location: SourceLocation(line: 3, column: 1),
                suppressedMetrics: SuppressedMetric.functionLevel)
        ]
        let result = ComplexityResult(filePath: "test.swift", functions: functions)
        let formatter = OutputFormatter()
        let options = OutputOptions(threshold: 10)

        // When
        let output = formatter.format(results: [result], format: .xcode, options: options)

        // Then
        #expect(output.isEmpty)
    }

    @Test("SARIF format reports one result per violated metric")
    func sarifFormat() throws {
        // Given
        let location = SourceLocation(line: 12, column: 5)
        let functions = [
            // Exceeds threshold 10 for both metrics; cognitive reaches 2x -> error
            FunctionComplexity(
                name: "complexFunc", signature: "func complexFunc()", cyclomaticComplexity: 11,
                cognitiveComplexity: 20, location: location),
            // Below threshold -> no results
            FunctionComplexity(
                name: "simpleFunc", signature: "func simpleFunc()", cyclomaticComplexity: 1,
                cognitiveComplexity: 0, location: SourceLocation(line: 1, column: 1)),
        ]
        let result = ComplexityResult(filePath: "Sources/test.swift", functions: functions)
        let formatter = OutputFormatter()
        let options = OutputOptions(threshold: 10)

        // When
        let output = formatter.format(results: [result], format: .sarif, options: options)

        // Then - valid JSON with SARIF envelope
        let json =
            try JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any] ?? [:]
        #expect(json["$schema"] as? String == "https://json.schemastore.org/sarif-2.1.0.json")
        #expect(json["version"] as? String == "2.1.0")

        let runs = json["runs"] as? [[String: Any]] ?? []
        let results = runs.first?["results"] as? [[String: Any]] ?? []
        #expect(results.count == 2)

        // Then - metric-specific rule ids and severity levels
        let levelsByRule = Dictionary(
            uniqueKeysWithValues: results.map {
                ($0["ruleId"] as? String ?? "", $0["level"] as? String ?? "")
            })
        #expect(levelsByRule["cyclomatic_complexity"] == "warning")  // 11 < 2x threshold
        #expect(levelsByRule["cognitive_complexity"] == "error")  // 20 >= 2x threshold

        let locations = results.first?["locations"] as? [[String: Any]] ?? []
        let physical = locations.first?["physicalLocation"] as? [String: Any] ?? [:]
        let region = physical["region"] as? [String: Any] ?? [:]
        let artifact = physical["artifactLocation"] as? [String: Any] ?? [:]
        #expect(region["startLine"] as? Int == 12)
        #expect(artifact["uri"] as? String == "Sources/test.swift")
        #expect(!output.contains("simpleFunc"))
    }

    @Test("SARIF format is empty without a threshold")
    func sarifFormatWithoutThreshold() throws {
        // Given
        let functions = [
            FunctionComplexity(
                name: "complexFunc", signature: "func complexFunc()", cyclomaticComplexity: 30,
                cognitiveComplexity: 30, location: SourceLocation(line: 1, column: 1))
        ]
        let result = ComplexityResult(filePath: "test.swift", functions: functions)
        let formatter = OutputFormatter()

        // When - no threshold and no configuration
        let output = formatter.format(results: [result], format: .sarif, options: OutputOptions())

        // Then - mirrors the exit-code semantics: nothing exceeds without a threshold
        let json =
            try JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any] ?? [:]
        let runs = json["runs"] as? [[String: Any]] ?? []
        let results = runs.first?["results"] as? [[String: Any]] ?? []
        #expect(results.isEmpty)
    }

    @Test("SARIF format skips a metric suppressed via // swift-complexity:disable")
    func sarifFormatWithSuppression() throws {
        // Given - both metrics exceed the threshold, but only cyclomatic is suppressed
        let functions = [
            FunctionComplexity(
                name: "partiallySuppressed", signature: "func partiallySuppressed()",
                cyclomaticComplexity: 20, cognitiveComplexity: 20,
                location: SourceLocation(line: 1, column: 1),
                suppressedMetrics: [.cyclomatic])
        ]
        let result = ComplexityResult(filePath: "test.swift", functions: functions)
        let formatter = OutputFormatter()
        let options = OutputOptions(threshold: 10)

        // When
        let output = formatter.format(results: [result], format: .sarif, options: options)

        // Then - only the non-suppressed metric produces a result
        let json =
            try JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any] ?? [:]
        let runs = json["runs"] as? [[String: Any]] ?? []
        let results = runs.first?["results"] as? [[String: Any]] ?? []
        #expect(results.count == 1)
        #expect(results.first?["ruleId"] as? String == "cognitive_complexity")
    }

    @Test("SARIF format reports low cohesion classes")
    func sarifFormatWithCohesion() throws {
        // Given
        let cohesions = [
            // LCOM4 >= 5 -> error
            ClassCohesion(
                name: "GodClass", type: .class, lcom4: 5, methodCount: 10, propertyCount: 8,
                location: SourceLocation(line: 3, column: 1)),
            // High cohesion -> no result
            ClassCohesion(
                name: "FocusedClass", type: .struct, lcom4: 1, methodCount: 3, propertyCount: 2,
                location: SourceLocation(line: 40, column: 1)),
        ]
        let result = ComplexityResult(
            filePath: "test.swift", functions: [], classCohesions: cohesions)
        let formatter = OutputFormatter()

        // When
        let output = formatter.format(results: [result], format: .sarif, options: OutputOptions())

        // Then
        let json =
            try JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: Any] ?? [:]
        let runs = json["runs"] as? [[String: Any]] ?? []
        let results = runs.first?["results"] as? [[String: Any]] ?? []
        #expect(results.count == 1)
        #expect(results.first?["ruleId"] as? String == "lcom4_cohesion")
        #expect(results.first?["level"] as? String == "error")
        #expect(output.contains("GodClass"))
        #expect(!output.contains("FocusedClass"))
    }

    @Test("SARIF and Xcode formats skip a suppressed low-cohesion type")
    func cohesionSuppressionSkipsJudgments() throws {
        // Given - low cohesion (lcom4 5 would normally be an error), suppressed
        let cohesions = [
            ClassCohesion(
                name: "SuppressedGodClass", type: .class, lcom4: 5, methodCount: 10,
                propertyCount: 8, location: SourceLocation(line: 3, column: 1),
                suppressedMetrics: [.lcom4])
        ]
        let result = ComplexityResult(
            filePath: "test.swift", functions: [], classCohesions: cohesions)
        let formatter = OutputFormatter()

        // When
        let sarif = formatter.format(results: [result], format: .sarif, options: OutputOptions())
        let xcode = formatter.format(results: [result], format: .xcode, options: OutputOptions())
        let json = formatter.format(results: [result], format: .json, options: OutputOptions())

        // Then - no judgment in sarif/xcode, but the value stays visible in json
        let parsed =
            try JSONSerialization.jsonObject(with: Data(sarif.utf8)) as? [String: Any] ?? [:]
        let runs = parsed["runs"] as? [[String: Any]] ?? []
        let sarifResults = runs.first?["results"] as? [[String: Any]] ?? []
        #expect(sarifResults.isEmpty)
        #expect(xcode.isEmpty)
        #expect(json.contains("SuppressedGodClass"))
        #expect(json.contains("\"lcom4\":5"))
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
        let analyzer = try ComplexityAnalyzer()

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
