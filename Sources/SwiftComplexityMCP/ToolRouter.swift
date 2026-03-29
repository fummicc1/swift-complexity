import MCP

/// Routes MCP tool calls to the appropriate handler.
enum ToolRouter {
    static func handle(_ params: CallTool.Parameters) async -> CallTool.Result {
        switch params.name {
        case "analyze_complexity":
            return await AnalyzeComplexityHandler.handle(params.arguments)
        case "analyze_code_string":
            return await AnalyzeCodeStringHandler.handle(params.arguments)
        default:
            return .init(content: [.text("Unknown tool: \(params.name)")], isError: true)
        }
    }
}
