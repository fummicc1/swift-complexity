import Foundation
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
}

/// Information about detected Nominal Type
struct DetectedNominal {
    let name: String
    let type: NominalTypeKind
    let members: MemberBlockItemListSyntax
    let location: SourceLocation
    /// Type-level metrics suppressed via a `// swift-complexity:disable`
    /// comment directly above this type declaration. Never cascades to the
    /// type's member functions.
    let suppressedMetrics: Set<SuppressedMetric>

    init(
        name: String,
        type: NominalTypeKind,
        members: MemberBlockItemListSyntax,
        location: SourceLocation,
        suppressedMetrics: Set<SuppressedMetric> = []
    ) {
        self.name = name
        self.type = type
        self.members = members
        self.location = location
        self.suppressedMetrics = suppressedMetrics
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

    // The scope is pinned to [.lcom4] rather than SuppressedMetric.typeLevel:
    // ClassCohesion must keep reporting only LCOM4 suppression so that output
    // without --coupling stays identical to previous releases. Coupling
    // suppression is collected independently by TypeRangeCollector.
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        let location = extractLocation(from: node.classKeyword)

        let detectedNominal = DetectedNominal(
            name: name,
            type: .class,
            members: node.memberBlock.members,
            location: location,
            suppressedMetrics: SuppressionParser.suppressedMetrics(
                in: node.leadingTrivia, applicableTo: [.lcom4])
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
            location: location,
            suppressedMetrics: SuppressionParser.suppressedMetrics(
                in: node.leadingTrivia, applicableTo: [.lcom4])
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
            location: location,
            suppressedMetrics: SuppressionParser.suppressedMetrics(
                in: node.leadingTrivia, applicableTo: [.lcom4])
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
