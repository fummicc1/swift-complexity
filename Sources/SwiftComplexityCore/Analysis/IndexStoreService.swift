import Foundation

#if IndexStore
    import IndexStoreDB
#endif

// MARK: - Errors

/// Errors raised while opening an index store, shared by every index-backed
/// analysis (LCOM4, coupling).
enum IndexStoreError: LocalizedError {
    case indexStoreNotFound(indexStorePath: String)
    case libIndexStoreNotFound(searchedPath: String)
    case toolchainRequired
    case initializationFailed(underlying: Error)
    case unavailableInThisBuild

    var errorDescription: String? {
        switch self {
        case .unavailableInThisBuild:
            return """
                Index-backed analysis (LCOM4, coupling) is not included in this build.
                Rebuild with 'swift build --traits IndexStore' or install a release binary.
                """
        case .indexStoreNotFound(let indexStorePath):
            return """
                Index store not found at '\(indexStorePath)'.
                Run 'swift build' first to generate the index.
                """
        case .libIndexStoreNotFound(let searchedPath):
            return "libIndexStore not found at: \(searchedPath)"
        case .toolchainRequired:
            #if os(Linux)
                return "--toolchain-path is required for index-backed analysis on Linux"
            #else
                return "Failed to detect Xcode toolchain. Please specify --toolchain-path"
            #endif
        case .initializationFailed(let error):
            return "Failed to initialize IndexStoreDB: \(error.localizedDescription)"
        }
    }
}

#if IndexStore

    // MARK: - Shared store handle

    /// A single opened IndexStoreDB shared between index-backed calculators so
    /// the database is populated once per run (opening costs seconds).
    ///
    /// `@unchecked Sendable`: IndexStoreDB is a class without a Sendable
    /// annotation, but its query API is documented thread-safe (SourceKit-LSP
    /// issues concurrent queries against one instance); this wrapper only ever
    /// exposes it immutably.
    struct SharedIndexStore: @unchecked Sendable {
        let database: IndexStoreDB
        let storePath: URL
    }

    // MARK: - Opening

    /// Opens IndexStoreDB instances. Centralizes libIndexStore discovery and the
    /// database configuration for every index-backed analysis.
    enum IndexStoreService {

        static func open(indexStorePath: URL, toolchainPath: URL? = nil) throws -> SharedIndexStore
        {
            guard FileManager.default.fileExists(atPath: indexStorePath.path) else {
                throw IndexStoreError.indexStoreNotFound(indexStorePath: indexStorePath.path)
            }

            let libIndexStorePath = try findLibIndexStore(toolchainPath: toolchainPath)

            do {
                // The database path is keyed to the store path so repeated runs
                // reuse the populated database per project without ever mixing
                // different projects' indexes in one database.
                //
                // waitUntilDoneInitializing guarantees queries see the fully
                // populated database; a one-shot CLI has no later delegate event
                // to await, so returning earlier would race the first query.
                let database = try IndexStoreDB(
                    storePath: indexStorePath.path,
                    databasePath: NSTemporaryDirectory()
                        + "swift-complexity-index-\(stableHash(of: indexStorePath.path)).db",
                    library: IndexStoreLibrary(dylibPath: libIndexStorePath),
                    waitUntilDoneInitializing: true
                )
                return SharedIndexStore(database: database, storePath: indexStorePath)
            } catch {
                throw IndexStoreError.initializationFailed(underlying: error)
            }
        }

        /// FNV-1a, chosen over `Hashable.hashValue` because the database path
        /// must stay identical across processes (hashValue is seeded per run).
        private static func stableHash(of string: String) -> String {
            var hash: UInt64 = 0xcbf2_9ce4_8422_2325
            for byte in string.utf8 {
                hash ^= UInt64(byte)
                hash = hash &* 0x0000_0100_0000_01B3
            }
            return String(hash, radix: 16)
        }

        // MARK: - libIndexStore discovery

        /// Searches for the libIndexStore dynamic library.
        /// - Parameter toolchainPath: Optional toolchain path (e.g.
        ///   `~/.local/share/swiftly/toolchains/swift-6.2`). On macOS, `nil`
        ///   auto-detects the Xcode toolchain. On Linux, this is required.
        private static func findLibIndexStore(toolchainPath: URL?) throws -> String {
            #if os(Linux)
                let libName = "libIndexStore.so"
            #else
                let libName = "libIndexStore.dylib"
            #endif

            // Expected structure: <toolchainPath>/usr/lib/libIndexStore.{so,dylib}
            if let toolchainPath = toolchainPath {
                let libPath =
                    toolchainPath
                    .appendingPathComponent("usr")
                    .appendingPathComponent("lib")
                    .appendingPathComponent(libName)
                guard FileManager.default.fileExists(atPath: libPath.path) else {
                    throw IndexStoreError.libIndexStoreNotFound(searchedPath: libPath.path)
                }
                return libPath.path
            }

            #if os(macOS)
                return try findLibIndexStoreFromXcode()
            #else
                throw IndexStoreError.toolchainRequired
            #endif
        }

        #if os(macOS)
            /// Auto-detects libIndexStore from the active Xcode toolchain.
            private static func findLibIndexStoreFromXcode() throws -> String {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
                process.arguments = ["--show-sdk-path"]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard
                    let sdkPath = String(data: data, encoding: .utf8)?.trimmingCharacters(
                        in: .whitespacesAndNewlines)
                else {
                    throw IndexStoreError.toolchainRequired
                }

                // /Applications/Xcode.app/.../SDKs/MacOSX.sdk
                // -> /Applications/Xcode.app/.../Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib
                let xcodeAppPath = sdkPath.components(separatedBy: "/Platforms/").first ?? ""
                let libPath =
                    "\(xcodeAppPath)/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib"

                guard FileManager.default.fileExists(atPath: libPath) else {
                    throw IndexStoreError.libIndexStoreNotFound(searchedPath: libPath)
                }

                return libPath
            }
        #endif
    }

#endif
