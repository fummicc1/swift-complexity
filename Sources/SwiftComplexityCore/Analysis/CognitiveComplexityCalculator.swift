import Foundation
import SwiftSyntax

class CognitiveComplexityCalculator: SyntaxVisitor {
    private var complexity: Int = 0
    private var nestingLevel: Int = 0
    private var logicalSequenceActive: Bool = false

    func calculate(for codeBlock: CodeBlockSyntax?) -> Int {
        guard let codeBlock = codeBlock else { return 0 }

        complexity = 0
        nestingLevel = 0
        logicalSequenceActive = false
        walk(codeBlock)
        return complexity
    }

    // If statements - increment + nesting penalty
    public override func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1 + nestingLevel
        nestingLevel += 1

        // Visit children with increased nesting
        for child in node.children(viewMode: .fixedUp) {
            walk(child)
        }

        nestingLevel -= 1
        return .skipChildren
    }

    // Guard statements - increment + nesting penalty
    public override func visit(_ node: GuardStmtSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1 + nestingLevel
        nestingLevel += 1

        for child in node.children(viewMode: .fixedUp) {
            walk(child)
        }

        nestingLevel -= 1
        return .skipChildren
    }

    // While loops - increment + nesting penalty
    public override func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1 + nestingLevel
        nestingLevel += 1

        for child in node.children(viewMode: .fixedUp) {
            walk(child)
        }

        nestingLevel -= 1
        return .skipChildren
    }

    // For loops - increment + nesting penalty
    public override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1 + nestingLevel
        nestingLevel += 1

        for child in node.children(viewMode: .fixedUp) {
            walk(child)
        }

        nestingLevel -= 1
        return .skipChildren
    }

    // Repeat-while loops - increment + nesting penalty
    public override func visit(_ node: RepeatStmtSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1 + nestingLevel
        nestingLevel += 1

        for child in node.children(viewMode: .fixedUp) {
            walk(child)
        }

        nestingLevel -= 1
        return .skipChildren
    }

    // Switch statement - single increment regardless of cases
    public override func visit(_ node: SwitchExprSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1 + nestingLevel
        nestingLevel += 1

        for child in node.children(viewMode: .fixedUp) {
            walk(child)
        }

        nestingLevel -= 1
        return .skipChildren
    }

    // Catch clauses - increment + nesting penalty
    public override func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1 + nestingLevel
        nestingLevel += 1

        for child in node.children(viewMode: .fixedUp) {
            walk(child)
        }

        nestingLevel -= 1
        return .skipChildren
    }

    // Ternary conditional operator - increment + nesting penalty
    public override func visit(_ node: TernaryExprSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1 + nestingLevel
        return .visitChildren
    }

    // Logical operators with sequence handling
    public override func visit(_ node: BinaryOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        let operatorText = node.operator.description.trimmingCharacters(
            in: .whitespacesAndNewlines)
        if operatorText == "&&" || operatorText == "||" {
            if !logicalSequenceActive {
                // First in sequence is free
                logicalSequenceActive = true
            } else {
                // Subsequent operators in sequence add complexity
                complexity += 1
            }
        } else {
            // Reset sequence for non-logical operators
            logicalSequenceActive = false
        }
        return .visitChildren
    }

    // Reset logical sequence when entering new expressions
    public override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        let savedSequenceState = logicalSequenceActive
        logicalSequenceActive = false

        for child in node.children(viewMode: .fixedUp) {
            walk(child)
        }

        logicalSequenceActive = savedSequenceState
        return .skipChildren
    }

    // Recursive function calls
    public override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        // This method detects recursive calls within the function body
        // For now, we skip this complexity as it requires more sophisticated analysis
        return .visitChildren
    }
}
