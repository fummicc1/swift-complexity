import Foundation
import MCP

@main
struct SwiftComplexityMCPServer {
    static func main() async throws {
        let server = Server(
            name: "swift-complexity",
            version: "1.0.0",
            capabilities: .init(
                tools: .init()
            )
        )

        await server.withMethodHandler(ListTools.self) { _ in
            .init(tools: ToolDefinitions.allTools)
        }

        await server.withMethodHandler(CallTool.self) { params in
            await ToolRouter.handle(params)
        }

        let transport = StdioTransport()
        try await server.start(transport: transport)

        // Keep the server running until the process is terminated
        try await Task.sleep(for: .seconds(Double.infinity))
    }
}
