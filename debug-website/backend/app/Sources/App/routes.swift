import Vapor

func routes(_ app: Application) throws {
    app.routes.defaultMaxBodySize = "500kb"
    // Health check endpoint
    app.get("health") { req async in
        return ["status": "ok"]
    }

    // Register API routes
    try app.register(collection: AnalyzerController())
}
