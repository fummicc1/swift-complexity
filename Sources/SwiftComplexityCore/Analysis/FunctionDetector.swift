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

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        return .skipChildren
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

    public override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        for binding in node.bindings {
            guard let accessorBlock = binding.accessorBlock else {
                continue  // Stored property, skip
            }

            // Check for shorthand computed property (CodeBlockItemListSyntax directly)
            if case .getter(let statements) = accessorBlock.accessors {
                appendShorthandComputedProperty(
                    from: node,
                    binding: binding,
                    statements: statements
                )
            }
            // Explicit accessors (get/set/didSet/willSet) are handled by visit(AccessorDeclSyntax)
        }

        return .visitChildren
    }

    public override func visit(_ node: AccessorDeclSyntax) -> SyntaxVisitorContinueKind {
        let accessorKind = node.accessorSpecifier.text

        // Try to find parent property name
        let propertyName = findParentPropertyName(from: node)
        let name = propertyName.map { "\($0).\(accessorKind)" } ?? accessorKind

        // Build better signature
        let signature = propertyName.map { "var \($0) { \(accessorKind) }" } ?? accessorKind
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

    private func extractPropertyName(from binding: PatternBindingSyntax) -> String? {
        if let identifier = binding.pattern.as(IdentifierPatternSyntax.self) {
            return identifier.identifier.text
        }
        return nil
    }

    private func extractComputedPropertySignature(
        from variable: VariableDeclSyntax,
        binding: PatternBindingSyntax
    ) -> String {
        var parts = [variable.bindingSpecifier.text, binding.pattern.description]
        if let typeAnnotation = binding.typeAnnotation {
            parts.append(typeAnnotation.description.trimmingCharacters(in: .whitespaces))
        }
        return parts.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func appendShorthandComputedProperty(
        from variable: VariableDeclSyntax,
        binding: PatternBindingSyntax,
        statements: CodeBlockItemListSyntax
    ) {
        guard let propertyName = extractPropertyName(from: binding) else {
            return  // Skip if property name cannot be extracted
        }

        let signature = extractComputedPropertySignature(from: variable, binding: binding)
        let location = extractLocation(from: binding.pattern)

        // Create a CodeBlockSyntax from the statements for consistency with other function bodies
        let codeBlock = CodeBlockSyntax(
            leftBrace: .leftBraceToken(),
            statements: statements,
            rightBrace: .rightBraceToken()
        )

        let detectedFunction = DetectedFunction(
            name: propertyName,
            signature: signature,
            body: codeBlock,
            location: location
        )

        detectedFunctions.append(detectedFunction)
    }

    private func findParentPropertyName(from node: AccessorDeclSyntax) -> String? {
        var current: Syntax? = Syntax(node)
        while let parent = current?.parent {
            if let binding = parent.as(PatternBindingSyntax.self),
                let identifier = binding.pattern.as(IdentifierPatternSyntax.self)
            {
                return identifier.identifier.text
            }
            current = parent
        }
        return nil
    }
}
