import Foundation
import IndexStoreDB
import SwiftSyntax

/// Nominal Type kind for LCOM4 cohesion analysis (class/struct/actor)
///
/// Note: Swift `enum` is excluded from LCOM4 analysis because:
/// - Enums cannot have instance stored properties (only computed properties and static properties)
/// - LCOM4 measures cohesion based on methods sharing access to instance state
/// - Without instance stored properties, the cohesion metric doesn't meaningfully apply
enum NominalTypeKind {
    case `class`
    case `struct`
    case actor

    var symbolKind: IndexSymbolKind {
        switch self {
        case .class: return .class
        case .struct: return .struct
        case .actor: return .class  // actor is also handled as IndexSymbolKind.class
        }
    }
}

/// Information about detected Nominal Type
struct DetectedNominal {
    let name: String
    let type: NominalTypeKind
    let members: MemberBlockItemListSyntax
    let location: SourceLocation

    init(
        name: String,
        type: NominalTypeKind,
        members: MemberBlockItemListSyntax,
        location: SourceLocation
    ) {
        self.name = name
        self.type = type
        self.members = members
        self.location = location
    }
}

/// Detection and information collection for Nominal Type (class/struct/actor)
class NominalTypeDetector: SyntaxVisitor {
    private var detectedTypes: [DetectedNominal] = []
    private var converter: SourceLocationConverter?

    override init(viewMode: SyntaxTreeViewMode = .sourceAccurate) {
        super.init(viewMode: viewMode)
    }

    /// Detect Nominal Types from source file
    func detectTypes(in sourceFile: SourceFileSyntax) -> [DetectedNominal] {
        detectedTypes.removeAll()
        converter = SourceLocationConverter(fileName: "", tree: sourceFile)
        walk(sourceFile)
        return detectedTypes
    }

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        let location = extractLocation(from: node.classKeyword)

        let detectedNominal = DetectedNominal(
            name: name,
            type: .class,
            members: node.memberBlock.members,
            location: location
        )

        detectedTypes.append(detectedNominal)

        return .visitChildren
    }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        let location = extractLocation(from: node.structKeyword)

        let detectedNominal = DetectedNominal(
            name: name,
            type: .struct,
            members: node.memberBlock.members,
            location: location
        )

        detectedTypes.append(detectedNominal)

        return .visitChildren
    }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        let location = extractLocation(from: node.actorKeyword)

        let detectedNominal = DetectedNominal(
            name: name,
            type: .actor,
            members: node.memberBlock.members,
            location: location
        )

        detectedTypes.append(detectedNominal)

        return .visitChildren
    }

    // MARK: - Helper Methods

    private func extractLocation(from token: TokenSyntax) -> SourceLocation {
        guard let converter = converter else {
            return SourceLocation(line: 0, column: 0)
        }

        let position = token.positionAfterSkippingLeadingTrivia
        let location = converter.location(for: position)

        return SourceLocation(
            line: location.line,
            column: location.column
        )
    }
}
