import Vapor

// Configures the application
public func configure(_ app: Application) async throws {
    // Serve files from /Public folder
    // app.middleware.use(FileMiddleware(publicDirectory: app.directory.publicDirectory))

    // Load application configuration based on environment
    let config = AppConfiguration.create(for: app.environment)

    // Configure CORS middleware
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: config.corsAllowedOrigin,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    let cors = CORSMiddleware(configuration: corsConfiguration)
    app.middleware.use(cors, at: .beginning)

    // Register routes
    try routes(app)
}
