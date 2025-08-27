import Foundation
import SwiftSyntax

struct DetectedFunction {
    let name: String
    let signature: String
    let body: CodeBlockSyntax?
    let location: SourceLocation

    init(name: String, signature: String, body: CodeBlockSyntax?, location: SourceLocation) {
        self.name = name
        self.signature = signature
        self.body = body
        self.location = location
    }
}

class FunctionDetector: SyntaxVisitor {
    private var detectedFunctions: [DetectedFunction] = []
    private var converter: SourceLocationConverter?

    func detectFunctions(in sourceFile: SourceFileSyntax) -> [DetectedFunction] {
        detectedFunctions.removeAll()
        converter = SourceLocationConverter(fileName: "", tree: sourceFile)
        walk(sourceFile)
        return detectedFunctions
    }

    public override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = extractFunctionName(from: node)
        let signature = extractFunctionSignature(from: node)
        let location = extractLocation(from: node.funcKeyword)

        let detectedFunction = DetectedFunction(
            name: name,
            signature: signature,
            body: node.body,
            location: location
        )

        detectedFunctions.append(detectedFunction)

        return .visitChildren
    }

    public override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = "init"
        let signature = extractInitializerSignature(from: node)
        let location = extractLocation(from: node.initKeyword)

        let detectedFunction = DetectedFunction(
            name: name,
            signature: signature,
            body: node.body,
            location: location
        )

        detectedFunctions.append(detectedFunction)

        return .visitChildren
    }

    public override func visit(_ node: DeinitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = "deinit"
        let signature = "deinit"
        let location = extractLocation(from: node.deinitKeyword)

        let detectedFunction = DetectedFunction(
            name: name,
            signature: signature,
            body: node.body,
            location: location
        )

        detectedFunctions.append(detectedFunction)

        return .visitChildren
    }

    public override func visit(_ node: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
        let accessorKind = node.accessorSpecifier.text
        let name = accessorKind
        let signature = accessorKind
        let location = extractLocation(from: node.accessorSpecifier)

        let detectedFunction = DetectedFunction(
            name: name,
            signature: signature,
            body: node.body,
            location: location
        )

        detectedFunctions.append(detectedFunction)

        return .visitChildren
    }

    private func extractFunctionName(from function: FunctionDeclSyntax) -> String {
        return function.name.text
    }

    private func extractFunctionSignature(from function: FunctionDeclSyntax) -> String {
        var signature = "func \(function.name.text)"

        if let genericParameterClause = function.genericParameterClause {
            signature += genericParameterClause.description
        }

        signature += function.signature.parameterClause.description

        if let returnClause = function.signature.returnClause {
            signature += " " + returnClause.description
        }

        return signature.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractInitializerSignature(from initializer: InitializerDeclSyntax) -> String {
        var signature = "init"

        if let genericParameterClause = initializer.genericParameterClause {
            signature += genericParameterClause.description
        }

        signature += initializer.signature.parameterClause.description

        return signature.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractLocation(from node: SyntaxProtocol) -> SourceLocation {
        guard let converter = converter else {
            return SourceLocation(line: 0, column: 0)
        }

        let sourceLocation = converter.location(for: node.positionAfterSkippingLeadingTrivia)
        return SourceLocation(line: sourceLocation.line, column: sourceLocation.column)
    }
}
