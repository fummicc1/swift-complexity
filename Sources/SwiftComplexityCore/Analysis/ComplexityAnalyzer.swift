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
    /// - Parameter indexStorePath: Optional IndexStore path for LCOM4 analysis (e.g., .build/debug/index/store). If nil, LCOM4 will be disabled.
    public init(indexStorePath: URL? = nil) throws {
        self.cyclomaticCalculator = CyclomaticComplexityCalculator(viewMode: .sourceAccurate)
        self.cognitiveCalculator = CognitiveComplexityCalculator(viewMode: .sourceAccurate)
        self.functionDetector = FunctionDetector(viewMode: .sourceAccurate)
        self.nominalTypeDetector = NominalTypeDetector(viewMode: .sourceAccurate)

        // LCOM4: High-accuracy (90-95%) semantic analysis with IndexStore-DB integration
        // Falls back to syntax-based analysis if IndexStore is not found
        if let indexStorePath = indexStorePath {
            self.lcomCalculator = try SemanticLCOMCalculator(indexStorePath: indexStorePath)
            self.enableLCOM4 = true
        } else {
            self.lcomCalculator = nil
            self.enableLCOM4 = false
        }
    }

    public func analyze(sourceFile: SourceFileSyntax, filePath: String) async throws
        -> ComplexityResult
    {
        // Existing function complexity calculation
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

        // LCOM4 calculation (only if enabled)
        var classCohesions: [ClassCohesion]? = nil

        if enableLCOM4, let lcomCalculator = lcomCalculator {
            let nominalTypes = nominalTypeDetector.detectTypes(in: sourceFile)
            var cohesions: [ClassCohesion] = []

            for detectedType in nominalTypes {
                let lcom4Value = try await lcomCalculator.calculate(for: detectedType)

                // Calculate member counts
                let (methods, properties) = extractMemberCounts(from: detectedType.members)

                // Convert NominalTypeKind to NominalType
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

    /// Count members (methods and properties)
    private func extractMemberCounts(from members: MemberBlockItemListSyntax) -> (
        methods: Int, properties: Int
    ) {
        var methodCount = 0
        var propertyCount = 0

        for member in members {
            let (propery, method) = member.countPropertyAndMethodCount()
            propertyCount += propery
            methodCount += method
        }

        return (methodCount, propertyCount)
    }
}

extension MemberBlockItemSyntax {
    fileprivate func countPropertyAndMethodCount() -> (property: Int, method: Int) {
        var propertyCount: Int = 0
        var methodCount: Int = 0

        // Method detection
        if let functionDecl = decl.as(FunctionDeclSyntax.self) {
            let isStatic = functionDecl.modifiers.contains { $0.name.text == "static" }
            if !isStatic {
                methodCount += 1
            }
        } else if decl.is(InitializerDeclSyntax.self) {
            methodCount += 1
        } else if decl.is(DeinitializerDeclSyntax.self) {
            methodCount += 1
        }
        // Property detection
        else if let variableDecl = decl.as(VariableDeclSyntax.self) {
            let (propery, method) = variableDecl.countPropertyAndMethodCount()
            propertyCount += propery
            methodCount += method
        }
        return (property: propertyCount, method: methodCount)
    }
}

extension VariableDeclSyntax {
    fileprivate func countPropertyAndMethodCount() -> (property: Int, method: Int) {
        var propertyCount: Int = 0

        let isStatic = modifiers.contains { $0.name.text == "static" }
        if !isStatic {
            for binding in bindings {
                if binding.pattern.is(IdentifierPatternSyntax.self) {
                    // Exclude computed properties
                    if binding.accessorBlock == nil {
                        propertyCount += 1
                    }
                }
            }
        }
        return (property: propertyCount, method: 0)
    }
}
