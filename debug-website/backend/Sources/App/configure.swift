import Vapor

// Configures the application
public func configure(_ app: Application) async throws {
    // Serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // Configure CORS middleware to allow frontend access
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .custom("https://swift-complexity.fummicc1.dev"),
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    app.middleware.use(cors, at: .beginning)

    // Register routes
    try routes(app)
}
