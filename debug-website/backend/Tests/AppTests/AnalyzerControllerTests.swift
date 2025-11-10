@testable import App
import XCTVapor
import SwiftComplexityCore

final class AnalyzerControllerTests: XCTestCase {
    var app: Application!

    override func setUp() async throws {
        app = try await Application.make(.testing)
        try await configure(app)
    }

    override func tearDown() async throws {
        try await app.asyncShutdown()
        app = nil
    }

    func testHealthCheck() async throws {
        try await app.test(.GET, "health") { res async in
            XCTAssertEqual(res.status, .ok)
        }
    }

    func testAnalyzeReturnsComplexityResult() async throws {
        let request = AnalyzeRequest(
            code: """
            func example(value: Int) -> String {
                if value > 0 {
                    return "Positive"
                }
                return "Not positive"
            }
            """,
            fileName: "test.swift",
            format: nil,
            showCyclomaticOnly: nil,
            showCognitiveOnly: nil,
            threshold: nil
        )

        try await app.test(.POST, "api/v1/analyze", beforeRequest: { req in
            try req.content.encode(request)
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
            let result = try res.content.decode(ComplexityResult.self)
            XCTAssertEqual(result.functions.count, 1)
        })
    }

    func testAnalyzeWithJSONFormat() async throws {
        let request = AnalyzeRequest(
            code: "func test() -> Int { return 1 }",
            fileName: "test.swift",
            format: .json,
            showCyclomaticOnly: nil,
            showCognitiveOnly: nil,
            threshold: nil
        )

        try await app.test(.POST, "api/v1/analyze", beforeRequest: { req in
            try req.content.encode(request)
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode(FormatResponse.self)
            XCTAssertTrue(response.formatted.contains("\"filePath\""))
        })
    }

    func testBatchAnalyze() async throws {
        let request = BatchAnalyzeRequest(
            files: [
                CodeFile(code: "func foo() -> Int { return 1 }", path: "foo.swift"),
                CodeFile(code: "func bar() -> Int { return 2 }", path: "bar.swift")
            ]
        )

        try await app.test(.POST, "api/v1/batch-analyze", beforeRequest: { req in
            try req.content.encode(request)
        }, afterResponse: { res async in
            XCTAssertEqual(res.status, .ok)
            let response = try res.content.decode(BatchAnalyzeResponse.self)
            XCTAssertEqual(response.results.count, 2)
        })
    }
}
