import Foundation
import SwiftSyntax

public protocol ComplexityAnalyzing {
  func analyze(sourceFile: SourceFileSyntax, filePath: String) async throws -> ComplexityResult
}

public actor ComplexityAnalyzer: ComplexityAnalyzing {
  private let cyclomaticCalculator: CyclomaticComplexityCalculator
  private let cognitiveCalculator: CognitiveComplexityCalculator
  private let functionDetector: FunctionDetector

  public init() {
    self.cyclomaticCalculator = CyclomaticComplexityCalculator(viewMode: .fixedUp)
    self.cognitiveCalculator = CognitiveComplexityCalculator(viewMode: .fixedUp)
    self.functionDetector = FunctionDetector(viewMode: .fixedUp)
  }

  public func analyze(sourceFile: SourceFileSyntax, filePath: String) async throws
    -> ComplexityResult
  {
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

    return ComplexityResult(
      filePath: filePath,
      functions: functionComplexities
    )
  }

}
