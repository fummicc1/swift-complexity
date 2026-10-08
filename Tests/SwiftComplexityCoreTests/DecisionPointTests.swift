import SwiftParser
import SwiftSyntax
import Testing

@testable import SwiftComplexityCore

/// Analyzes `source` and returns the reported functions keyed by name.
private func analyze(_ source: String) async throws -> [String: FunctionComplexity] {
    let analyzer = try ComplexityAnalyzer()
    let result = try await analyzer.analyze(
        sourceFile: Parser.parse(source: source), filePath: "test.swift")
    return Dictionary(
        result.functions.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
}

/// Per-construct scoring, run through `ComplexityAnalyzer` so the operator
/// folding step is exercised exactly as the CLI runs it.
@Suite("Decision points", .tags(.unit, .calculators))
struct DecisionPointTests {
    @Suite("Cyclomatic")
    struct Cyclomatic {
        @Test("Ternary operator adds +1")
        func ternary() async throws {
            let functions = try await analyze(
                """
                func f(_ flag: Bool) -> Int {
                    flag ? 1 : 2
                }
                """)
            // base(1) + ternary(1)
            #expect(functions["f"]?.cyclomaticComplexity == 2)
        }

        @Test("Nested ternaries each add +1")
        func nestedTernary() async throws {
            let functions = try await analyze(
                """
                func f(_ a: Bool, _ b: Bool) -> Int {
                    a ? 1 : b ? 2 : 3
                }
                """)
            // base(1) + ternary(1) + ternary(1)
            #expect(functions["f"]?.cyclomaticComplexity == 3)
        }

        @Test("Each nil-coalescing operator adds +1")
        func nilCoalescing() async throws {
            let functions = try await analyze(
                """
                func f(_ a: Int?, _ b: Int?) -> Int {
                    a ?? b ?? 0
                }
                """)
            // base(1) + ??(1) + ??(1)
            #expect(functions["f"]?.cyclomaticComplexity == 3)
        }

        @Test("Ternary and ?? inside call arguments are counted")
        func operatorsInArguments() async throws {
            let functions = try await analyze(
                """
                func f(_ a: Bool, _ b: Int?) -> Int {
                    max(a ? 1 : 2, b ?? 0)
                }
                """)
            // base(1) + ternary(1) + ??(1)
            #expect(functions["f"]?.cyclomaticComplexity == 3)
        }

        @Test("Logical operators keep adding +1 each")
        func logicalOperators() async throws {
            let functions = try await analyze(
                """
                func f(_ a: Bool, _ b: Bool, _ c: Bool) -> Int {
                    if a && b || c { return 1 }
                    return 0
                }
                """)
            // base(1) + if(1) + &&(1) + ||(1)
            #expect(functions["f"]?.cyclomaticComplexity == 4)
        }

        @Test("Unknown custom operators don't stop the rest of the expression from folding")
        func customOperators() async throws {
            let functions = try await analyze(
                """
                infix operator ~~~
                func f(_ a: Int, _ b: Int, _ c: Bool?) -> Int {
                    (a ~~~ b) && a > 0 ? 1 : (c ?? false ? 2 : 3)
                }
                """)
            // base(1) + &&(1) + ternary(1) + ??(1) + ternary(1)
            #expect(functions["f"]?.cyclomaticComplexity == 5)
        }

        @Test("if adds +1 per comma-separated condition")
        func ifConditions() async throws {
            let functions = try await analyze(
                """
                func f(_ a: Int?, _ b: Bool) -> Int {
                    if let a, b { return a }
                    return 0
                }
                """)
            // base(1) + if let a(1) + b(1)
            #expect(functions["f"]?.cyclomaticComplexity == 3)
        }

        @Test("else if adds +1 per comma-separated condition")
        func elseIfConditions() async throws {
            let functions = try await analyze(
                """
                func f(_ a: Int?, _ b: Bool) -> Int {
                    if b {
                        return 1
                    } else if let a, a > 0 {
                        return a
                    }
                    return 0
                }
                """)
            // base(1) + if(1) + else if let a(1) + a > 0(1)
            #expect(functions["f"]?.cyclomaticComplexity == 4)
        }

        @Test("guard adds +1 per comma-separated condition")
        func guardConditions() async throws {
            let functions = try await analyze(
                """
                func f(_ a: Int?, _ b: Bool) -> Int {
                    guard let a, b else { return 0 }
                    return a
                }
                """)
            // base(1) + guard let a(1) + b(1)
            #expect(functions["f"]?.cyclomaticComplexity == 3)
        }

        @Test("while adds +1 per comma-separated condition")
        func whileConditions() async throws {
            let functions = try await analyze(
                """
                func f(_ items: [Int]) {
                    var iterator = items.makeIterator()
                    while let item = iterator.next(), item > 0 {
                        print(item)
                    }
                }
                """)
            // base(1) + while let(1) + item > 0(1)
            #expect(functions["f"]?.cyclomaticComplexity == 3)
        }

        @Test("for adds +1, and +1 more for a where clause")
        func forWhere() async throws {
            let functions = try await analyze(
                """
                func plain(_ xs: [Int]) {
                    for x in xs { print(x) }
                }
                func filtered(_ xs: [Int]) {
                    for x in xs where x > 0 { print(x) }
                }
                """)
            // base(1) + for(1)
            #expect(functions["plain"]?.cyclomaticComplexity == 2)
            // base(1) + for(1) + where(1)
            #expect(functions["filtered"]?.cyclomaticComplexity == 3)
        }

        @Test("switch counts each case label; switch and default add nothing")
        func switchCases() async throws {
            let functions = try await analyze(
                """
                func f(_ x: Int) -> Int {
                    switch x {
                    case 0: return 0
                    case 1, 2: return 1
                    default: return 2
                    }
                }
                """)
            // base(1) + case 0(1) + case 1, 2(1)
            #expect(functions["f"]?.cyclomaticComplexity == 3)
        }

        @Test("Nested functions are reported on their own, not added to the outer function")
        func nestedFunction() async throws {
            let functions = try await analyze(
                """
                func outer(_ a: Bool) -> Int {
                    func inner(_ b: Bool) -> Int {
                        if b { return 1 }
                        return 0
                    }
                    if a { return inner(a) }
                    return 0
                }
                """)
            // outer: base(1) + if(1); inner's if is not counted here
            #expect(functions["outer"]?.cyclomaticComplexity == 2)
            // inner: base(1) + if(1)
            #expect(functions["inner"]?.cyclomaticComplexity == 2)
        }

        @Test("Members of local types and local computed properties stay out of the outer function")
        func localDeclarations() async throws {
            let functions = try await analyze(
                """
                func outer(_ a: Bool) -> Int {
                    struct Local {
                        func method(_ b: Bool) -> Int { b ? 1 : 0 }
                    }
                    var computed: Int { a ? 1 : 0 }
                    return Local().method(a) + computed
                }
                """)
            #expect(functions["outer"]?.cyclomaticComplexity == 1)
            #expect(functions["method"]?.cyclomaticComplexity == 2)
            #expect(functions["computed"]?.cyclomaticComplexity == 2)
        }

        @Test("Closures still count toward the enclosing function")
        func closure() async throws {
            let functions = try await analyze(
                """
                func f(_ items: [Int]) -> [Int] {
                    items.map { x in
                        if x > 0 { return x }
                        return 0
                    }
                }
                """)
            // base(1) + if inside the closure(1)
            #expect(functions["f"]?.cyclomaticComplexity == 2)
        }

        @Test("#if counts only the most complex clause")
        func conditionalCompilation() async throws {
            let functions = try await analyze(
                """
                func f(_ a: Bool, _ b: Bool) -> Int {
                    #if DEBUG
                        if a { return 1 }
                    #elseif TESTING
                        if a && b { return 2 }
                    #else
                        return 3
                    #endif
                    return 0
                }
                """)
            // base(1) + max(DEBUG: 1, TESTING: 2, else: 0)
            #expect(functions["f"]?.cyclomaticComplexity == 3)
        }

        @Test("Folding keeps function locations unchanged")
        func locationsUnchanged() async throws {
            let functions = try await analyze(
                """
                let x = 1 + 2 * 3

                    func f(_ a: Bool) -> Int { a ? 1 : 2 }
                """)
            #expect(functions["f"]?.location == SourceLocation(line: 3, column: 5))
        }
    }

    @Suite("Cognitive")
    struct Cognitive {
        @Test("Ternary operator adds +1")
        func ternary() async throws {
            let functions = try await analyze(
                """
                func f(_ flag: Bool) -> Int {
                    flag ? 1 : 2
                }
                """)
            #expect(functions["f"]?.cognitiveComplexity == 1)
        }

        @Test("Ternary inside an if gets the nesting penalty")
        func nestedTernary() async throws {
            let functions = try await analyze(
                """
                func f(_ a: Bool, _ b: Bool) -> Int {
                    if a {
                        return b ? 1 : 2
                    }
                    return 0
                }
                """)
            // if(1) + ternary(1 + 1 nesting)
            #expect(functions["f"]?.cognitiveComplexity == 3)
        }

        @Test("Nil-coalescing adds nothing (SonarSource: null-coalescing is shorthand)")
        func nilCoalescing() async throws {
            let functions = try await analyze(
                """
                func f(_ a: Int?, _ b: Int?) -> Int {
                    a ?? b ?? 0
                }
                """)
            #expect(functions["f"]?.cognitiveComplexity == 0)
        }

        @Test("Nested functions are reported on their own, not added to the outer function")
        func nestedFunction() async throws {
            let functions = try await analyze(
                """
                func outer(_ a: Bool) -> Int {
                    func inner(_ b: Bool) -> Int {
                        if b { return 1 }
                        return 0
                    }
                    if a { return inner(a) }
                    return 0
                }
                """)
            #expect(functions["outer"]?.cognitiveComplexity == 1)
            #expect(functions["inner"]?.cognitiveComplexity == 1)
        }

        @Test("#if counts only the most complex clause")
        func conditionalCompilation() async throws {
            let functions = try await analyze(
                """
                func f(_ a: Bool, _ b: Bool) -> Int {
                    #if DEBUG
                        if a { return 1 }
                    #else
                        if a {
                            if b { return 2 }
                        }
                    #endif
                    return 0
                }
                """)
            // max(DEBUG: if(1), else: if(1) + nested if(1 + 1 nesting))
            #expect(functions["f"]?.cognitiveComplexity == 3)
        }

        @Test("#if inside a nested block keeps the surrounding nesting level")
        func conditionalCompilationNesting() async throws {
            let functions = try await analyze(
                """
                func f(_ a: Bool, _ b: Bool) {
                    if a {
                        #if DEBUG
                            if b { print(b) }
                        #endif
                    }
                }
                """)
            // if(1) + nested if(1 + 1 nesting)
            #expect(functions["f"]?.cognitiveComplexity == 3)
        }
    }
}
