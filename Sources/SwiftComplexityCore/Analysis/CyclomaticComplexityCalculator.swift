import Foundation
import SwiftSyntax

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

    public override func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind {
        complexity += node.conditions.count
        return .visitChildren
    }

    public override func visit(_ node: GuardStmtSyntax) -> SyntaxVisitorContinueKind {
        complexity += node.conditions.count
        return .visitChildren
    }

    public override func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind {
        complexity += node.conditions.count
        return .visitChildren
    }

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

    private func decisions(in node: some SyntaxProtocol) -> Int {
        let saved = complexity
        complexity = 0
        walk(node)
        let result = complexity
        complexity = saved
        return result
    }
}
