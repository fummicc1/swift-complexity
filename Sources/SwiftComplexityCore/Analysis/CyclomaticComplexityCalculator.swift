import Foundation
import SwiftSyntax

/// Counts decision points in a function body (McCabe).
///
/// Expects an operator-folded tree (see `ComplexityAnalyzer.foldingOperators(in:)`):
/// ternaries and `??` are only visible as `TernaryExprSyntax` /
/// `InfixOperatorExprSyntax` after folding.
class CyclomaticComplexityCalculator: FunctionBodyVisitor {
    private var complexity: Int = 0

    func calculate(for codeBlock: CodeBlockSyntax?) -> Int {
        guard let codeBlock = codeBlock else { return 1 }

        complexity = 1  // Base complexity
        walk(codeBlock)
        return complexity
    }

    // If statements: +1 per comma-separated condition (`if let a, b` is two decisions)
    public override func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind {
        complexity += node.conditions.count
        return .visitChildren
    }

    // Guard statements: +1 per comma-separated condition
    public override func visit(_ node: GuardStmtSyntax) -> SyntaxVisitorContinueKind {
        complexity += node.conditions.count
        return .visitChildren
    }

    // While loops: +1 per comma-separated condition
    public override func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind {
        complexity += node.conditions.count
        return .visitChildren
    }

    // For loops: +1, and +1 more for a `where` filter
    public override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
        complexity += node.whereClause == nil ? 1 : 2
        return .visitChildren
    }

    // Repeat-while loops
    public override func visit(_ node: RepeatStmtSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1
        return .visitChildren
    }

    // Switch cases
    public override func visit(_ node: SwitchCaseSyntax) -> SyntaxVisitorContinueKind {
        if case .case = node.label {
            complexity += 1
        }
        return .visitChildren
    }

    // Catch clauses
    public override func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1
        return .visitChildren
    }

    // Ternary conditional operator
    public override func visit(_ node: TernaryExprSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1
        return .visitChildren
    }

    // `#if` / `#elseif` / `#else`: only one clause is compiled, so count the
    // most complex clause instead of the sum of all of them.
    public override func visit(_ node: IfConfigDeclSyntax) -> SyntaxVisitorContinueKind {
        let clauseComplexities = node.clauses.map { clause in
            clause.elements.map { decisions(in: $0) } ?? 0
        }
        complexity += clauseComplexities.max() ?? 0
        return .skipChildren
    }

    // Logical operators (AND)
    public override func visit(_ node: BinaryOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        let operatorText = node.operator.description.trimmingCharacters(
            in: .whitespacesAndNewlines)
        if operatorText == "&&" || operatorText == "||" {
            complexity += 1
        }
        return .visitChildren
    }

    // Nil coalescing operator
    public override func visit(_ node: InfixOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        let operatorText = node.operator.description.trimmingCharacters(
            in: .whitespacesAndNewlines)
        if operatorText == "??" {
            complexity += 1
        }
        return .visitChildren
    }

    /// Decision points inside `node` alone, without touching the running total.
    private func decisions(in node: some SyntaxProtocol) -> Int {
        let saved = complexity
        complexity = 0
        walk(node)
        let result = complexity
        complexity = saved
        return result
    }
}
