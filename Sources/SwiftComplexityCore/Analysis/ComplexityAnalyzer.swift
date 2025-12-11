import Foundation
import SwiftSyntax

public protocol ComplexityAnalyzing {
    func analyze(sourceFile: SourceFileSyntax, filePath: String) async throws -> ComplexityResult
}

public actor ComplexityAnalyzer: ComplexityAnalyzing {
    private let cyclomaticCalculator: CyclomaticComplexityCalculator
    private let cognitiveCalculator: CognitiveComplexityCalculator
    private let functionDetector: FunctionDetector
    private let nominalTypeDetector: NominalTypeDetector
    private let lcomCalculator: SemanticLCOMCalculator?
    private let enableLCOM4: Bool

    /// Initialize the analyzer
    /// - Parameter projectRoot: Optional project root URL for LCOM4 analysis. If nil, LCOM4 will be disabled.
    public init(projectRoot: URL? = nil) throws {
        self.cyclomaticCalculator = CyclomaticComplexityCalculator(viewMode: .sourceAccurate)
        self.cognitiveCalculator = CognitiveComplexityCalculator(viewMode: .sourceAccurate)
        self.functionDetector = FunctionDetector(viewMode: .sourceAccurate)
        self.nominalTypeDetector = NominalTypeDetector(viewMode: .sourceAccurate)

        // LCOM4は将来的にSourceKit-LSP統合で有効化予定
        // 現在は基本的な構文解析のみ実装
        if let projectRoot = projectRoot {
            self.lcomCalculator = try SemanticLCOMCalculator(projectRoot: projectRoot)
            self.enableLCOM4 = true
        } else {
            self.lcomCalculator = nil
            self.enableLCOM4 = false
        }
    }

    public func analyze(sourceFile: SourceFileSyntax, filePath: String) async throws
        -> ComplexityResult
    {
        // 既存の関数複雑度計算
        let functions = functionDetector.detectFunctions(in: sourceFile)
        var functionComplexities: [FunctionComplexity] = []

        for function in functions {
            let cyclomaticComplexity = cyclomaticCalculator.calculate(for: function.body)
            let cognitiveComplexity = cognitiveCalculator.calculate(for: function.body)

            let functionComplexity = FunctionComplexity(
                name: function.name,
                signature: function.signature,
                cyclomaticComplexity: cyclomaticComplexity,
                cognitiveComplexity: cognitiveComplexity,
                location: function.location
            )

            functionComplexities.append(functionComplexity)
        }

        // LCOM4計算（有効な場合のみ）
        var classCohesions: [ClassCohesion]? = nil

        if enableLCOM4, let lcomCalculator = lcomCalculator {
            let nominalTypes = nominalTypeDetector.detectTypes(in: sourceFile)
            var cohesions: [ClassCohesion] = []

            for detectedType in nominalTypes {
                let lcom4Value = try await lcomCalculator.calculate(for: detectedType)

                // メンバー数を計算
                let (methods, properties) = extractMemberCounts(from: detectedType.members)

                // NominalTypeKindをNominalTypeに変換
                let nominalType: NominalType
                switch detectedType.type {
                case .class:
                    nominalType = .class
                case .struct:
                    nominalType = .struct
                case .actor:
                    nominalType = .actor
                }

                let cohesion = ClassCohesion(
                    name: detectedType.name,
                    type: nominalType,
                    lcom4: lcom4Value,
                    methodCount: methods,
                    propertyCount: properties,
                    location: detectedType.location
                )

                cohesions.append(cohesion)
            }

            classCohesions = cohesions.isEmpty ? nil : cohesions
        }

        return ComplexityResult(
            filePath: filePath,
            functions: functionComplexities,
            classCohesions: classCohesions
        )
    }

    // MARK: - Private Helpers

    /// メンバー数をカウント（メソッドとプロパティ）
    private func extractMemberCounts(from members: MemberBlockItemListSyntax) -> (
        methods: Int, properties: Int
    ) {
        var methodCount = 0
        var propertyCount = 0

        for member in members {
            // メソッド検出
            if let functionDecl = member.decl.as(FunctionDeclSyntax.self) {
                let isStatic = functionDecl.modifiers.contains { $0.name.text == "static" }
                if !isStatic {
                    methodCount += 1
                }
            } else if member.decl.is(InitializerDeclSyntax.self) {
                methodCount += 1
            } else if member.decl.is(DeinitializerDeclSyntax.self) {
                methodCount += 1
            }
            // プロパティ検出
            else if let variableDecl = member.decl.as(VariableDeclSyntax.self) {
                let isStatic = variableDecl.modifiers.contains { $0.name.text == "static" }
                if !isStatic {
                    for binding in variableDecl.bindings {
                        if binding.pattern.is(IdentifierPatternSyntax.self) {
                            // computed propertyは除外
                            if binding.accessorBlock == nil {
                                propertyCount += 1
                            }
                        }
                    }
                }
            }
        }

        return (methodCount, propertyCount)
    }

}
