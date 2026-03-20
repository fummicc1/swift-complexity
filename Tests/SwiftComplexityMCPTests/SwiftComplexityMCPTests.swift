import MCP
import SwiftComplexityCore
import Testing

@testable import SwiftComplexityMCP

// MARK: - Tool Definition Tests

@Suite("Tool Definitions")
struct ToolDefinitionTests {
    @Test("All tools are defined")
    func allToolsDefined() {
        #expect(ToolDefinitions.allTools.count == 2)
        let names = ToolDefinitions.allTools.map(\.name)
        #expect(names.contains("analyze_complexity"))
        #expect(names.contains("analyze_code_string"))
    }

    @Test("analyze_complexity tool has correct name and description")
    func analyzeComplexityToolMetadata() {
        let tool = ToolDefinitions.analyzeComplexity
        #expect(tool.name == "analyze_complexity")
        #expect(tool.description?.contains("complexity") == true)
    }

    @Test("analyze_code_string tool has correct name and description")
    func analyzeCodeStringToolMetadata() {
        let tool = ToolDefinitions.analyzeCodeString
        #expect(tool.name == "analyze_code_string")
        #expect(tool.description?.contains("Swift code string") == true)
    }
}

// MARK: - ParamExtractor Tests

@Suite("ParamExtractor")
struct ParamExtractorTests {
    @Test("Extract string value")
    func extractString() {
        let args: [String: Value] = ["key": .string("hello")]
        #expect(ParamExtractor.string("key", from: args) == "hello")
        #expect(ParamExtractor.string("missing", from: args) == nil)
    }

    @Test("Extract string array value")
    func extractStringArray() {
        let args: [String: Value] = ["paths": .array([.string("a.swift"), .string("b.swift")])]
        let result = ParamExtractor.stringArray("paths", from: args)
        #expect(result == ["a.swift", "b.swift"])
        #expect(ParamExtractor.stringArray("missing", from: args) == nil)
    }

    @Test("Extract bool value with default")
    func extractBool() {
        let args: [String: Value] = ["flag": .bool(true)]
        #expect(ParamExtractor.bool("flag", from: args) == true)
        #expect(ParamExtractor.bool("missing", from: args) == false)
        #expect(ParamExtractor.bool("missing", from: args, default: true) == true)
    }

    @Test("Extract int value")
    func extractInt() {
        let args: [String: Value] = ["threshold": .int(10)]
        #expect(ParamExtractor.int("threshold", from: args) == 10)
        #expect(ParamExtractor.int("missing", from: args) == nil)
    }

    @Test("Extract from nil arguments")
    func extractFromNil() {
        #expect(ParamExtractor.string("key", from: nil) == nil)
        #expect(ParamExtractor.stringArray("key", from: nil) == nil)
        #expect(ParamExtractor.bool("key", from: nil) == false)
        #expect(ParamExtractor.int("key", from: nil) == nil)
    }
}

// MARK: - AnalyzeCodeStringHandler Tests

@Suite("AnalyzeCodeStringHandler")
struct AnalyzeCodeStringHandlerTests {
    /// Helper to extract text content from a CallTool.Result
    private func textContent(_ result: CallTool.Result) -> String? {
        result.content.first.flatMap {
            if case .text(let t) = $0 { return t }
            return nil
        }
    }

    @Test("Analyze simple Swift function")
    func analyzeSimpleFunction() async {
        let code = """
            func greet(name: String) -> String {
                if name.isEmpty {
                    return "Hello, World!"
                }
                return "Hello, \\(name)!"
            }
            """
        let args: [String: Value] = ["code": .string(code)]
        let result = await AnalyzeCodeStringHandler.handle(args)

        #expect(result.isError != true)
        let text = result.content.first.flatMap {
            if case .text(let t) = $0 { return t }
            return nil
        }
        #expect(text != nil)
        #expect(text?.contains("greet") == true)
    }

    @Test("Analyze with custom file name")
    func analyzeWithCustomFileName() async {
        let code = "func foo() { }"
        let args: [String: Value] = [
            "code": .string(code),
            "file_name": .string("test.swift"),
        ]
        let result = await AnalyzeCodeStringHandler.handle(args)

        #expect(result.isError != true)
        let text = result.content.first.flatMap {
            if case .text(let t) = $0 { return t }
            return nil
        }
        #expect(text?.contains("test.swift") == true)
    }

    @Test("Missing code parameter returns error")
    func missingCodeParameter() async {
        let result = await AnalyzeCodeStringHandler.handle(nil)
        #expect(result.isError == true)
    }

    @Test("Empty code string is handled")
    func emptyCodeString() async {
        let args: [String: Value] = ["code": .string("")]
        let result = await AnalyzeCodeStringHandler.handle(args)
        // Empty code should parse fine, just with no functions
        #expect(result.isError != true)
    }
}

// MARK: - AnalyzeComplexityHandler Validation Tests

@Suite("AnalyzeComplexityHandler Validation")
struct AnalyzeComplexityHandlerValidationTests {
    @Test("Missing paths returns error")
    func missingPaths() async {
        let result = await AnalyzeComplexityHandler.handle(nil)
        #expect(result.isError == true)
    }

    @Test("Empty paths array returns error")
    func emptyPaths() async {
        let args: [String: Value] = ["paths": .array([])]
        let result = await AnalyzeComplexityHandler.handle(args)
        #expect(result.isError == true)
    }

    @Test("Mutually exclusive flags returns error")
    func mutuallyExclusiveFlags() async {
        let args: [String: Value] = [
            "paths": .array([.string("test.swift")]),
            "cyclomatic_only": .bool(true),
            "cognitive_only": .bool(true),
        ]
        let result = await AnalyzeComplexityHandler.handle(args)
        #expect(result.isError == true)

        let text = result.content.first.flatMap {
            if case .text(let t) = $0 { return t }
            return nil
        }
        #expect(text?.contains("mutually exclusive") == true)
    }

    @Test("LCOM4 without index_store_path returns error")
    func lcom4WithoutIndexStorePath() async {
        let args: [String: Value] = [
            "paths": .array([.string("test.swift")]),
            "lcom4": .bool(true),
        ]
        let result = await AnalyzeComplexityHandler.handle(args)
        #expect(result.isError == true)

        let text = result.content.first.flatMap {
            if case .text(let t) = $0 { return t }
            return nil
        }
        #expect(text?.contains("index_store_path") == true)
    }

    @Test("Invalid path returns error")
    func invalidPath() async {
        let args: [String: Value] = [
            "paths": .array([.string("/nonexistent/path/to/file.swift")])
        ]
        let result = await AnalyzeComplexityHandler.handle(args)
        #expect(result.isError == true)
    }
}

// MARK: - OutputFormatter LCOM4 Integration Tests

@Suite("OutputFormatter LCOM4 Integration")
struct OutputFormatterLCOM4Tests {
    @Test("Text format shows function table even when showLCOM4 is true")
    func textFormatShowsFunctionsWithLCOM4() {
        let result = ComplexityResult(
            filePath: "Test.swift",
            functions: [
                FunctionComplexity(
                    name: "foo",
                    signature: "func foo()",
                    cyclomaticComplexity: 3,
                    cognitiveComplexity: 2,
                    location: SourceLocation(line: 1, column: 1)
                )
            ],
            classCohesions: [
                ClassCohesion(
                    name: "TestClass",
                    type: .class,
                    lcom4: 2,
                    methodCount: 3,
                    propertyCount: 2,
                    location: SourceLocation(line: 10, column: 1)
                )
            ]
        )

        let formatter = OutputFormatter()
        let options = OutputOptions(showLCOM4: true)
        let output = formatter.format(results: [result], format: .text, options: options)

        // Function table must be present even with showLCOM4
        #expect(output.contains("foo"))
        #expect(output.contains("Function/Method"))
        // Cohesion table must also be present
        #expect(output.contains("LCOM4"))
        #expect(output.contains("TestClass"))
    }

    @Test("JSON format includes both functions and cohesion when showLCOM4 is true")
    func jsonFormatIncludesBothWithLCOM4() {
        let result = ComplexityResult(
            filePath: "Test.swift",
            functions: [
                FunctionComplexity(
                    name: "bar",
                    signature: "func bar()",
                    cyclomaticComplexity: 5,
                    cognitiveComplexity: 3,
                    location: SourceLocation(line: 1, column: 1)
                )
            ],
            classCohesions: [
                ClassCohesion(
                    name: "MyClass",
                    type: .struct,
                    lcom4: 1,
                    methodCount: 2,
                    propertyCount: 1,
                    location: SourceLocation(line: 5, column: 1)
                )
            ]
        )

        let formatter = OutputFormatter()
        let options = OutputOptions(showLCOM4: true)
        let output = formatter.format(results: [result], format: .json, options: options)

        #expect(output.contains("bar"))
        #expect(output.contains("MyClass"))
    }
}

// MARK: - Threshold Filtering Tests

@Suite("Threshold Filtering")
struct ThresholdFilteringTests {
    @Test("Threshold filters functions but preserves cohesion data")
    func thresholdPreservesCohesion() {
        let result = ComplexityResult(
            filePath: "Test.swift",
            functions: [
                FunctionComplexity(
                    name: "simple",
                    signature: "func simple()",
                    cyclomaticComplexity: 1,
                    cognitiveComplexity: 0,
                    location: SourceLocation(line: 1, column: 1)
                ),
                FunctionComplexity(
                    name: "complex",
                    signature: "func complex()",
                    cyclomaticComplexity: 15,
                    cognitiveComplexity: 20,
                    location: SourceLocation(line: 10, column: 1)
                ),
            ],
            classCohesions: [
                ClassCohesion(
                    name: "TestClass",
                    type: .class,
                    lcom4: 1,
                    methodCount: 2,
                    propertyCount: 1,
                    location: SourceLocation(line: 1, column: 1)
                )
            ]
        )

        let formatter = OutputFormatter()
        let options = OutputOptions(showLCOM4: true, threshold: 10)
        let output = formatter.format(results: [result], format: .json, options: options)

        // Both functions should be in raw output (filtering is done by handler, not formatter)
        #expect(output.contains("simple"))
        #expect(output.contains("complex"))
        // Cohesion data must be preserved regardless of threshold
        #expect(output.contains("TestClass"))
    }
}

// MARK: - ToolRouter Tests

@Suite("ToolRouter")
struct ToolRouterTests {
    @Test("Unknown tool returns error")
    func unknownTool() async {
        let params = CallTool.Parameters(name: "nonexistent_tool", arguments: nil)
        let result = await ToolRouter.handle(params)
        #expect(result.isError == true)

        let text = result.content.first.flatMap {
            if case .text(let t) = $0 { return t }
            return nil
        }
        #expect(text?.contains("Unknown tool") == true)
    }
}
