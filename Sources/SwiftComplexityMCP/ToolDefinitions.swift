import MCP

/// Defines all MCP tools exposed by the swift-complexity server.
enum ToolDefinitions {
    static let allTools: [Tool] = [
        analyzeComplexity,
        analyzeCodeString,
    ]

    static let analyzeComplexity = Tool(
        name: "analyze_complexity",
        description:
            "Analyze Swift files or directories for cyclomatic complexity, cognitive complexity, and LCOM4 class cohesion metrics",
        inputSchema: .object([
            "type": .string("object"),
            "required": .array([.string("paths")]),
            "properties": .object([
                "paths": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")]),
                    "description": .string("Swift file paths or directory paths to analyze"),
                ]),
                "recursive": .object([
                    "type": .string("boolean"),
                    "default": .bool(false),
                    "description": .string("Recursively analyze directories"),
                ]),
                "exclude": .object([
                    "type": .string("array"),
                    "items": .object(["type": .string("string")]),
                    "default": .array([]),
                    "description": .string("Exclude file patterns (regex format)"),
                ]),
                "threshold": .object([
                    "type": .string("integer"),
                    "description": .string(
                        "Complexity threshold — only return functions at or above this value"),
                ]),
                "format": .object([
                    "type": .string("string"),
                    "enum": .array([.string("text"), .string("json")]),
                    "default": .string("json"),
                    "description": .string("Output format (json recommended for programmatic use)"),
                ]),
                "cyclomatic_only": .object([
                    "type": .string("boolean"),
                    "default": .bool(false),
                    "description": .string("Show only cyclomatic complexity"),
                ]),
                "cognitive_only": .object([
                    "type": .string("boolean"),
                    "default": .bool(false),
                    "description": .string("Show only cognitive complexity"),
                ]),
                "lcom4": .object([
                    "type": .string("boolean"),
                    "default": .bool(false),
                    "description": .string("Include LCOM4 class cohesion metrics"),
                ]),
                "index_store_path": .object([
                    "type": .string("string"),
                    "description": .string(
                        "IndexStore path for LCOM4 analysis (required when lcom4 is true)"),
                ]),
                "toolchain_path": .object([
                    "type": .string("string"),
                    "description": .string("Swift toolchain path for LCOM4 (required on Linux)"),
                ]),
            ]),
        ])
    )

    static let analyzeCodeString = Tool(
        name: "analyze_code_string",
        description:
            "Analyze a Swift code string directly for complexity metrics without requiring a file on disk",
        inputSchema: .object([
            "type": .string("object"),
            "required": .array([.string("code")]),
            "properties": .object([
                "code": .object([
                    "type": .string("string"),
                    "description": .string("Swift source code to analyze"),
                ]),
                "file_name": .object([
                    "type": .string("string"),
                    "default": .string("<stdin>"),
                    "description": .string("Virtual file name for the analysis result"),
                ]),
            ]),
        ])
    )
}
