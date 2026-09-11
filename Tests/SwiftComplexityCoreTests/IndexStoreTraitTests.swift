import Foundation
import Testing

@testable import SwiftComplexityCore

@Suite("IndexStore trait")
struct IndexStoreTraitTests {

    /// CI sets this env var in every --traits IndexStore step; without this check a trait that stops reaching the test module would silently compile the index suites out
    @Test("Trait reaches the test module when CI expects it")
    func traitReachesTests() {
        guard ProcessInfo.processInfo.environment["SWIFT_COMPLEXITY_EXPECT_INDEXSTORE_TRAIT"] != nil
        else { return }
        #if !IndexStore
            Issue.record(
                "SWIFT_COMPLEXITY_EXPECT_INDEXSTORE_TRAIT is set but IndexStore is not compiled in")
        #endif
    }

    #if !IndexStore
        @Test("Opening an index store without the trait fails with a rebuild hint")
        func analyzerRejectsIndexStoreWithoutTrait() {
            let anyExistingPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            #expect(throws: IndexStoreError.self) {
                try ComplexityAnalyzer(indexStorePath: anyExistingPath)
            }
            do {
                _ = try ComplexityAnalyzer(indexStorePath: anyExistingPath)
            } catch let error as IndexStoreError {
                #expect(error.localizedDescription.contains("--traits IndexStore"))
            } catch {
                Issue.record("Unexpected error type: \(error)")
            }
        }
    #endif
}
