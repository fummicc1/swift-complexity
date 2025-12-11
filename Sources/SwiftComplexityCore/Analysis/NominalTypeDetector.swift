import Foundation
import IndexStoreDB
import SwiftSyntax

/// Nominal Type（class/struct/actor）の種類
enum NominalTypeKind {
    case `class`
    case `struct`
    case actor

    var symbolKind: IndexSymbolKind {
        switch self {
        case .class: return .class
        case .struct: return .struct
        case .actor: return .class  // actorもIndexSymbolKind.classとして扱われる
        }
    }
}

/// 検出されたNominal Typeの情報
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

/// Nominal Type（class/struct/actor）の検出と情報収集
class NominalTypeDetector: SyntaxVisitor {
    private var detectedTypes: [DetectedNominal] = []
    private var converter: SourceLocationConverter?

    override init(viewMode: SyntaxTreeViewMode = .sourceAccurate) {
        super.init(viewMode: viewMode)
    }

    /// ソースファイルからNominal Typeを検出
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
