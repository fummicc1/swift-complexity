import SwiftSyntax

/// One type or extension declaration's source extent within a file.
///
/// Collected for coupling analysis: index references that carry no
/// `containedBy` relation (e.g. enum case payload annotations) are attributed
/// to the innermost declaration whose extent contains their location.
struct TypeRangeEntry: Sendable, Equatable {
    enum DeclKind: Sendable, Equatable {
        case nominal(NominalType)
        case ext(extendedTypeName: String)
    }

    /// Display name; nested types use dotted form (e.g. "Outer.Inner").
    /// Extension entries carry the extended type's name as written.
    let name: String

    let declKind: DeclKind

    let startLine: Int
    let startColumn: Int
    let endLine: Int
    let endColumn: Int

    /// Type-level suppression parsed from the declaration's leading trivia.
    /// Always empty for extensions: suppression is scoped to the primary
    /// declaration so multiple extensions cannot contradict each other.
    let suppressedMetrics: Set<SuppressedMetric>

    /// The type name coupling edges attribute to; extensions resolve to the
    /// extended type.
    var resolvedTypeName: String {
        switch declKind {
        case .nominal: return name
        case .ext(let extendedTypeName): return extendedTypeName
        }
    }

    func contains(line: Int, column: Int) -> Bool {
        if line < startLine || line > endLine { return false }
        if line == startLine && column < startColumn { return false }
        if line == endLine && column > endColumn { return false }
        return true
    }
}

/// Per-file lookup of type declaration extents for location-based attribution.
struct TypeRangeIndex: Sendable {
    let entries: [TypeRangeEntry]

    /// The innermost declaration containing the given position, or `nil` at
    /// top level. Nested declarations start later than their containers, so
    /// the containing entry with the greatest start position is the innermost.
    /// Files hold few type declarations; a linear scan keeps the rule obvious.
    func innermostType(line: Int, column: Int) -> TypeRangeEntry? {
        entries
            .filter { $0.contains(line: line, column: column) }
            .max { ($0.startLine, $0.startColumn) < ($1.startLine, $1.startColumn) }
    }
}

/// Collects type declaration extents (class/struct/enum/actor/protocol and
/// extensions) with their type-level suppression state.
///
/// Deliberately separate from `NominalTypeDetector`: that detector feeds
/// LCOM4 and must keep reporting lcom4-only suppression for unchanged output,
/// while coupling needs enum/protocol/extension coverage on top.
final class TypeRangeCollector: SyntaxVisitor {
    private var converter: SourceLocationConverter
    private var entries: [TypeRangeEntry] = []
    private var nameStack: [String] = []

    static func collect(from sourceFile: SourceFileSyntax, filePath: String) -> TypeRangeIndex {
        let collector = TypeRangeCollector(
            converter: SourceLocationConverter(fileName: filePath, tree: sourceFile))
        collector.walk(sourceFile)
        return TypeRangeIndex(entries: collector.entries)
    }

    private init(converter: SourceLocationConverter) {
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    // MARK: - Nominal declarations

    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        enter(node, simpleName: node.name.text, kind: .nominal(.class))
    }

    override func visitPost(_ node: ClassDeclSyntax) { nameStack.removeLast() }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        enter(node, simpleName: node.name.text, kind: .nominal(.struct))
    }

    override func visitPost(_ node: StructDeclSyntax) { nameStack.removeLast() }

    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        enter(node, simpleName: node.name.text, kind: .nominal(.actor))
    }

    override func visitPost(_ node: ActorDeclSyntax) { nameStack.removeLast() }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        enter(node, simpleName: node.name.text, kind: .nominal(.enum))
    }

    override func visitPost(_ node: EnumDeclSyntax) { nameStack.removeLast() }

    override func visit(_ node: ProtocolDeclSyntax) -> SyntaxVisitorContinueKind {
        enter(node, simpleName: node.name.text, kind: .nominal(.protocol))
    }

    override func visitPost(_ node: ProtocolDeclSyntax) { nameStack.removeLast() }

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        let extendedName = node.extendedType.trimmedDescription
        return enter(node, simpleName: extendedName, kind: .ext(extendedTypeName: extendedName))
    }

    override func visitPost(_ node: ExtensionDeclSyntax) { nameStack.removeLast() }

    // MARK: - Recording

    private func enter(
        _ node: some SyntaxProtocol,
        simpleName: String,
        kind: TypeRangeEntry.DeclKind
    ) -> SyntaxVisitorContinueKind {
        let start = converter.location(for: node.positionAfterSkippingLeadingTrivia)
        let end = converter.location(for: node.endPosition)
        let dottedName = (nameStack + [simpleName]).joined(separator: ".")

        entries.append(
            TypeRangeEntry(
                name: dottedName,
                declKind: kind,
                startLine: start.line,
                startColumn: start.column,
                endLine: end.line,
                endColumn: end.column,
                suppressedMetrics: suppression(for: kind, leadingTrivia: node.leadingTrivia)
            ))

        nameStack.append(simpleName)
        return .visitChildren
    }

    private func suppression(
        for kind: TypeRangeEntry.DeclKind, leadingTrivia: Trivia
    ) -> Set<SuppressedMetric> {
        switch kind {
        case .nominal(.class), .nominal(.struct), .nominal(.actor):
            return SuppressionParser.suppressedMetrics(
                in: leadingTrivia, applicableTo: SuppressedMetric.typeLevel)
        case .nominal(.enum), .nominal(.protocol):
            // LCOM4 does not apply to enums/protocols, so a bare disable
            // must not leak lcom4 into their suppression set.
            return SuppressionParser.suppressedMetrics(
                in: leadingTrivia, applicableTo: [.coupling])
        case .ext:
            return []
        }
    }
}
