import Vapor

struct AppConfiguration {
    let corsAllowedOrigin: CORSMiddleware.AllowOriginSetting

    static func create(for environment: Environment) -> AppConfiguration {
        switch environment {
        case .development:
            return AppConfiguration(corsAllowedOrigin: .all)
        default:
            return AppConfiguration(corsAllowedOrigin: .custom("https://swift-complexity.fummicc1.dev"))
        }
    }
}
