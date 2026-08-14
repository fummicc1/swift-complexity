import Foundation

/// Represents the complexity analysis result for a single file
public struct ComplexityResult: Codable, Sendable {
    /// Path to the analyzed file
    public let filePath: String

    /// Array of function/method complexities found in the file
    public let functions: [FunctionComplexity]

    /// Array of class/struct/actor cohesion metrics (optional for backward compatibility)
    public let classCohesions: [ClassCohesion]?

    /// Statistical summary for the file
    public let summary: FileSummary

    /// Cohesion summary (optional, only present when LCOM4 analysis is enabled)
    public let cohesionSummary: CohesionSummary?

    /// Coupling metrics for types defined in this file (optional, only present
    /// when coupling analysis is enabled)
    public let typeCouplings: [TypeCoupling]?

    /// Coupling summary (optional, only present when coupling analysis is enabled)
    public let couplingSummary: CouplingSummary?

    public init(
        filePath: String,
        functions: [FunctionComplexity],
        classCohesions: [ClassCohesion]? = nil,
        typeCouplings: [TypeCoupling]? = nil
    ) {
        self.filePath = filePath
        self.functions = functions
        self.classCohesions = classCohesions
        self.summary = FileSummary(functions: functions)
        self.cohesionSummary = classCohesions.map { CohesionSummary(classes: $0) }
        self.typeCouplings = typeCouplings
        self.couplingSummary = typeCouplings.map { CouplingSummary(types: $0) }
    }

    /// Returns a copy of this result with coupling metrics attached. Coupling
    /// is computed in a whole-project pass after per-file analysis, so results
    /// are rebuilt rather than mutated; the summaries recompute
    /// deterministically from the same inputs.
    public func attaching(typeCouplings: [TypeCoupling]) -> ComplexityResult {
        ComplexityResult(
            filePath: filePath,
            functions: functions,
            classCohesions: classCohesions,
            typeCouplings: typeCouplings
        )
    }
}

/// Statistical summary for a file's complexity metrics
public struct FileSummary: Codable, Sendable {
    /// Total number of functions analyzed
    public let totalFunctions: Int

    /// Average cyclomatic complexity
    public let averageCyclomaticComplexity: Double

    /// Average cognitive complexity
    public let averageCognitiveComplexity: Double

    /// Maximum cyclomatic complexity found
    public let maxCyclomaticComplexity: Int

    /// Maximum cognitive complexity found
    public let maxCognitiveComplexity: Int

    /// Total cyclomatic complexity
    public let totalCyclomaticComplexity: Int

    /// Total cognitive complexity
    public let totalCognitiveComplexity: Int

    public init(functions: [FunctionComplexity]) {
        self.totalFunctions = functions.count

        if functions.isEmpty {
            self.averageCyclomaticComplexity = 0.0
            self.averageCognitiveComplexity = 0.0
            self.maxCyclomaticComplexity = 0
            self.maxCognitiveComplexity = 0
            self.totalCyclomaticComplexity = 0
            self.totalCognitiveComplexity = 0
        } else {
            let cyclomaticValues = functions.map(\.cyclomaticComplexity)
            let cognitiveValues = functions.map(\.cognitiveComplexity)

            self.totalCyclomaticComplexity = cyclomaticValues.reduce(0, +)
            self.totalCognitiveComplexity = cognitiveValues.reduce(0, +)

            self.averageCyclomaticComplexity =
                Double(totalCyclomaticComplexity) / Double(totalFunctions)
            self.averageCognitiveComplexity =
                Double(totalCognitiveComplexity) / Double(totalFunctions)

            self.maxCyclomaticComplexity = cyclomaticValues.max() ?? 0
            self.maxCognitiveComplexity = cognitiveValues.max() ?? 0
        }
    }
}
