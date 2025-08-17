import Foundation
import SwiftSyntax

class CyclomaticComplexityCalculator: SyntaxVisitor {
    private var complexity: Int = 0

    func calculate(for codeBlock: CodeBlockSyntax?) -> Int {
        guard let codeBlock = codeBlock else { return 1 }

        complexity = 1  // Base complexity
        walk(codeBlock)
        return complexity
    }

    // If statements
    public override func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1
        return .visitChildren
    }

    // Guard statements
    public override func visit(_ node: GuardStmtSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1
        return .visitChildren
    }

    // While loops
    public override func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1
        return .visitChildren
    }

    // For loops
    public override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1
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
}
