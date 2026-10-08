import SwiftSyntax

/// Base visitor for metrics measured over a single function body.
///
/// `FunctionDetector` reports nested functions, members of local types, and
/// local computed properties / observers as functions of their own, so their
/// bodies must not also add to the enclosing function's score. Closures are
/// not reported separately and stay part of the enclosing function.
class FunctionBodyVisitor: SyntaxVisitor {
    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: AccessorBlockSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }
}
