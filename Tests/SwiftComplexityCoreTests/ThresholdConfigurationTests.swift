import Foundation
import Testing

@testable import SwiftComplexityCore

@Suite("ThresholdConfiguration")
struct ThresholdConfigurationTests {

    // MARK: - Rule Matching

    @Suite("Rule matching")
    struct RuleMatchingTests {
        @Test("Prefix-only rule matches by prefix")
        func prefixOnly() {
            let rule = ThresholdRule(prefix: "Toilet", threshold: 12)
            #expect(rule.matches(typeName: "ToiletRepository"))
            #expect(rule.matches(typeName: "ToiletUseCase"))
            #expect(!rule.matches(typeName: "UserRepository"))
        }

        @Test("Suffix-only rule matches by suffix")
        func suffixOnly() {
            let rule = ThresholdRule(suffix: "Repository", threshold: 5)
            #expect(rule.matches(typeName: "ToiletRepository"))
            #expect(rule.matches(typeName: "UserRepository"))
            #expect(!rule.matches(typeName: "ToiletUseCase"))
        }

        @Test("Prefix + suffix rule requires both")
        func prefixAndSuffix() {
            let rule = ThresholdRule(prefix: "User", suffix: "UseCase", threshold: 7)
            #expect(rule.matches(typeName: "UserUseCase"))
            #expect(!rule.matches(typeName: "UserRepository"))
            #expect(!rule.matches(typeName: "AdminUseCase"))
        }

        @Test("Rule without prefix or suffix never matches")
        func emptyRuleNeverMatches() {
            let rule = ThresholdRule(threshold: 3)
            #expect(!rule.matches(typeName: "Anything"))
            #expect(!rule.matches(typeName: ""))
        }
    }

    // MARK: - Threshold Resolution

    @Suite("Threshold resolution")
    struct ResolutionTests {
        private let config = ThresholdConfiguration(
            defaultThreshold: 10,
            rules: [
                ThresholdRule(prefix: "Toilet", threshold: 12),
                ThresholdRule(suffix: "Repository", threshold: 5),
                ThresholdRule(suffix: "UseCase", threshold: 15),
            ]
        )

        @Test("Multiple matches pick the strictest (lowest) threshold")
        func strictestWins() {
            // ToiletRepository matches prefix(Toilet=12) and suffix(Repository=5) → 5
            #expect(config.threshold(forTypeName: "ToiletRepository", fallback: nil) == 5)
        }

        @Test("Single match uses that rule's threshold (can be looser than default)")
        func singleMatchAllowsLooser() {
            // ToiletUseCase matches prefix(Toilet=12) and suffix(UseCase=15) → 12
            #expect(config.threshold(forTypeName: "ToiletUseCase", fallback: nil) == 12)
            // PaymentUseCase matches only suffix(UseCase=15) → 15 (looser than default 10)
            #expect(config.threshold(forTypeName: "PaymentUseCase", fallback: nil) == 15)
        }

        @Test("Unmatched type falls back to default when no CLI threshold")
        func unmatchedUsesDefault() {
            #expect(config.threshold(forTypeName: "SomeService", fallback: nil) == 10)
        }

        @Test("CLI threshold overrides config default for unmatched types")
        func cliOverridesDefault() {
            #expect(config.threshold(forTypeName: "SomeService", fallback: 3) == 3)
        }

        @Test("Matched rule is not capped by CLI threshold")
        func matchedIgnoresFallback() {
            // Even with a stricter CLI fallback, a matched rule wins (15 for UseCase).
            #expect(config.threshold(forTypeName: "PaymentUseCase", fallback: 3) == 15)
        }

        @Test("Free function (nil type) uses fallback then default")
        func freeFunction() {
            #expect(config.threshold(forTypeName: nil, fallback: nil) == 10)
            #expect(config.threshold(forTypeName: nil, fallback: 4) == 4)
        }

        @Test("Empty configuration relies solely on fallback")
        func emptyConfig() {
            let empty = ThresholdConfiguration.empty
            #expect(empty.isEmpty)
            #expect(empty.threshold(forTypeName: "AnyRepository", fallback: nil) == nil)
            #expect(empty.threshold(forTypeName: "AnyRepository", fallback: 8) == 8)
        }
    }

    // MARK: - isExceeded

    @Suite("isExceeded")
    struct IsExceededTests {
        private func function(type: String?, cyclomatic: Int, cognitive: Int) -> FunctionComplexity
        {
            FunctionComplexity(
                name: "f", signature: "func f()",
                cyclomaticComplexity: cyclomatic, cognitiveComplexity: cognitive,
                location: SourceLocation(line: 1, column: 1),
                enclosingTypeName: type
            )
        }

        @Test("Function in matched type is flagged at the rule threshold")
        func flaggedByRule() {
            let config = ThresholdConfiguration(
                rules: [ThresholdRule(suffix: "Repository", threshold: 5)])
            let fn = function(type: "UserRepository", cyclomatic: 5, cognitive: 0)
            #expect(config.isExceeded(fn, fallback: nil))
        }

        @Test("Function below the rule threshold is not flagged")
        func notFlaggedBelowRule() {
            let config = ThresholdConfiguration(
                rules: [ThresholdRule(suffix: "Repository", threshold: 8)])
            let fn = function(type: "UserRepository", cyclomatic: 5, cognitive: 3)
            #expect(!config.isExceeded(fn, fallback: nil))
        }

        @Test("Cognitive complexity alone can trigger the flag")
        func cognitiveTriggers() {
            let config = ThresholdConfiguration(
                rules: [ThresholdRule(suffix: "Repository", threshold: 5)])
            let fn = function(type: "UserRepository", cyclomatic: 1, cognitive: 6)
            #expect(config.isExceeded(fn, fallback: nil))
        }

        @Test("No applicable threshold means never flagged")
        func neverFlaggedWithoutThreshold() {
            let config = ThresholdConfiguration.empty
            let fn = function(type: nil, cyclomatic: 99, cognitive: 99)
            #expect(!config.isExceeded(fn, fallback: nil))
        }
    }

    // MARK: - YAML Loading

    @Suite("YAML loading")
    struct LoadingTests {
        private func writeTempYAML(_ contents: String) throws -> String {
            let dir = FileManager.default.temporaryDirectory
            let url = dir.appendingPathComponent("swift-complexity-test-\(UUID().uuidString).yml")
            try contents.write(to: url, atomically: true, encoding: .utf8)
            return url.path
        }

        @Test("Decodes default threshold and rules from YAML")
        func decodesYAML() throws {
            let yaml = """
                defaultThreshold: 10
                rules:
                  - prefix: Toilet
                    threshold: 12
                  - suffix: Repository
                    threshold: 5
                """
            let path = try writeTempYAML(yaml)
            defer { try? FileManager.default.removeItem(atPath: path) }

            let config = try ThresholdConfiguration.load(fromFileAtPath: path)
            #expect(config.defaultThreshold == 10)
            #expect(config.rules.count == 2)
            #expect(config.rules[0].prefix == "Toilet")
            #expect(config.rules[0].suffix == nil)
            #expect(config.rules[0].threshold == 12)
            #expect(config.rules[1].suffix == "Repository")
            #expect(config.rules[1].threshold == 5)
        }

        @Test("Decodes config without a default threshold")
        func decodesWithoutDefault() throws {
            let yaml = """
                rules:
                  - suffix: UseCase
                    threshold: 15
                """
            let path = try writeTempYAML(yaml)
            defer { try? FileManager.default.removeItem(atPath: path) }

            let config = try ThresholdConfiguration.load(fromFileAtPath: path)
            #expect(config.defaultThreshold == nil)
            #expect(config.rules.count == 1)
            #expect(config.rules[0].threshold == 15)
        }

        @Test("Missing file throws fileNotFound")
        func missingFileThrows() {
            #expect(throws: ThresholdConfiguration.LoadError.self) {
                _ = try ThresholdConfiguration.load(
                    fromFileAtPath: "/nonexistent/swift-complexity.yml")
            }
        }
    }
}
