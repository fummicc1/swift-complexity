import Foundation
import SwiftSyntax

class CognitiveComplexityCalculator: SyntaxVisitor {
    private var complexity: Int = 0
    private var nestingLevel: Int = 0
    private var logicalSequenceActive: Bool = false
    private var isInElseBody: Bool = false

    func calculate(for codeBlock: CodeBlockSyntax?) -> Int {
        guard let codeBlock = codeBlock else { return 0 }

        complexity = 0
        nestingLevel = 0
        logicalSequenceActive = false
        isInElseBody = false
        walk(codeBlock)
        return complexity
    }

    // If statements - increment + nesting penalty
    // Special handling: elseBody is visited at the same nesting level as the if statement
    // This ensures 'else if' is treated as a continuation, not a nested structure
    public override func visit(_ node: IfExprSyntax) -> SyntaxVisitorContinueKind {
        // If this is an 'else if', it's a continuation and only adds +1
        // Otherwise, add complexity with current nesting level
        if isInElseBody {
            complexity += 1
            isInElseBody = false  // Reset flag after consuming it
        } else {
            complexity += 1 + nestingLevel
        }

        // Increase nesting for the if-body
        nestingLevel += 1
        walk(node.body)

        // Return to original nesting level for else-body
        // This treats 'else if' as a continuation at the same level
        nestingLevel -= 1
        if let elseBody = node.elseBody {
            // Check if this is a standalone 'else' (not 'else if')
            // An 'else if' has a conditionElementList child, while standalone 'else' doesn't
            let hasConditionList = elseBody.children(viewMode: .sourceAccurate)
                .contains { $0.kind == .conditionElementList }

            if hasConditionList {
                // This is 'else if' - set flag for the nested IfExprSyntax
                isInElseBody = true
            } else {
                // Standalone else adds +1 complexity without nesting penalty
                complexity += 1
            }

            walk(elseBody)
        }

        return .skipChildren
    }

    // Guard statements - increment only (no nesting penalty)
    // The guard condition itself doesn't create nesting
    public override func visit(_ node: GuardStmtSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1
        return .visitChildren
    }

    // While loops - increment + nesting penalty
    public override func visit(_ node: WhileStmtSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1 + nestingLevel
        nestingLevel += 1

        for child in node.children(viewMode: .sourceAccurate) {
            walk(child)
        }

        nestingLevel -= 1
        return .skipChildren
    }

    // For loops - increment + nesting penalty
    public override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1 + nestingLevel
        nestingLevel += 1

        for child in node.children(viewMode: .sourceAccurate) {
            walk(child)
        }

        nestingLevel -= 1
        return .skipChildren
    }

    // Repeat-while loops - increment + nesting penalty
    public override func visit(_ node: RepeatStmtSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1 + nestingLevel
        nestingLevel += 1

        for child in node.children(viewMode: .sourceAccurate) {
            walk(child)
        }

        nestingLevel -= 1
        return .skipChildren
    }

    // Switch statement - single increment regardless of cases
    public override func visit(_ node: SwitchExprSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1 + nestingLevel
        nestingLevel += 1

        for child in node.children(viewMode: .sourceAccurate) {
            walk(child)
        }

        nestingLevel -= 1
        return .skipChildren
    }

    // Catch clauses - increment + nesting penalty
    public override func visit(_ node: CatchClauseSyntax) -> SyntaxVisitorContinueKind {
        complexity += 1 + nestingLevel
        nestingLevel += 1

        for child in node.children(viewMode: .sourceAccurate) {
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

        for child in node.children(viewMode: .sourceAccurate) {
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
