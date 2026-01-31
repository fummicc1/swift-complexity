import Foundation
import IndexStoreDB
import SwiftSyntax

// MARK: - Error Types

enum LCOMError: LocalizedError {
    case noMembersFound(className: String)
    case parsingFailed(className: String, underlying: Error)
    case indexStoreNotFound(indexStorePath: String)
    case libIndexStoreNotFound(searchedPath: String)
    case toolchainRequired
    case indexDBInitializationFailed(underlying: Error)
    case symbolNotFound(symbolName: String, usr: String?)
    case queryTimeout(query: String)

    var errorDescription: String? {
        switch self {
        case .noMembersFound(let className):
            return "No members found in class '\(className)'"
        case .parsingFailed(let className, let error):
            return "Failed to parse class '\(className)': \(error.localizedDescription)"
        case .indexStoreNotFound(let indexStorePath):
            return """
                Index store not found at '\(indexStorePath)'.
                Run 'swift build' first to generate the index.
                """
        case .libIndexStoreNotFound(let searchedPath):
            return "libIndexStore not found at: \(searchedPath)"
        case .toolchainRequired:
            #if os(Linux)
                return "--toolchain-path is required for LCOM4 analysis on Linux"
            #else
                return "Failed to detect Xcode toolchain. Please specify --toolchain-path"
            #endif
        case .indexDBInitializationFailed(let error):
            return "Failed to initialize IndexStoreDB: \(error.localizedDescription)"
        case .symbolNotFound(let symbolName, let usr):
            let usrInfo = usr.map { " (USR: \($0))" } ?? ""
            return "Symbol '\(symbolName)' not found in index\(usrInfo)"
        case .queryTimeout(let query):
            return "IndexStoreDB query timed out: \(query)"
        }
    }
}

// MARK: - Union-Find Data Structure

/// Union-Find for efficient connected component counting
class UnionFind {
    private var parent: [String: String] = [:]
    private var rank: [String: Int] = [:]

    init(elements: [String]) {
        for element in elements {
            parent[element] = element
            rank[element] = 0
        }
    }

    /// Finds the root of an element (with path compression)
    func find(_ element: String) -> String {
        guard let p = parent[element] else { return element }
        if p != element {
            parent[element] = find(p)  // Path compression
        }
        return parent[element]!
    }

    /// Merges two elements into the same set
    func union(_ a: String, _ b: String) {
        let rootA = find(a)
        let rootB = find(b)

        if rootA == rootB { return }

        let rankA = rank[rootA] ?? 0
        let rankB = rank[rootB] ?? 0

        if rankA < rankB {
            parent[rootA] = rootB
        } else if rankA > rankB {
            parent[rootB] = rootA
        } else {
            parent[rootB] = rootA
            rank[rootA] = rankA + 1
        }
    }

    /// Calculates the number of connected components
    func componentCount() -> Int {
        var roots = Set<String>()
        for element in parent.keys {
            roots.insert(find(element))
        }
        return roots.count
    }
}

// MARK: - Semantic LCOM Calculator

/// LCOM4 calculation engine with IndexStore-DB integration (high accuracy: 90-95%)
actor SemanticLCOMCalculator {
    private let indexStoreDB: IndexStoreDB
    private let indexStorePath: URL

    /// Initialize with explicit IndexStore path
    /// - Parameters:
    ///   - indexStorePath: Direct path to the IndexStore (e.g., .build/debug/index/store)
    ///   - toolchainPath: Optional Swift toolchain path (e.g., /path/to/toolchain/usr).
    ///                    On macOS, if nil, Xcode toolchain is auto-detected.
    ///                    On Linux, this is required.
    init(indexStorePath: URL, toolchainPath: URL? = nil) throws {
        self.indexStorePath = indexStorePath

        guard FileManager.default.fileExists(atPath: indexStorePath.path) else {
            throw LCOMError.indexStoreNotFound(indexStorePath: indexStorePath.path)
        }

        // Get libIndexStore path (platform-specific)
        let libIndexStorePath = try Self.findLibIndexStore(toolchainPath: toolchainPath)

        self.indexStoreDB = try IndexStoreDB(
            storePath: indexStorePath.path,
            databasePath: NSTemporaryDirectory() + "lcom4-index.db",
            library: IndexStoreLibrary(dylibPath: libIndexStorePath)
        )
    }

    /// Calculates LCOM4 value for Nominal Type (class/struct/actor)
    func calculate(for detectedType: DetectedNominal) async throws -> Int {
        // 1. Get USR from DetectedNominal
        guard
            let classUSR = try await findUSR(
                for: detectedType.name,
                kind: detectedType.type.symbolKind
            )
        else {
            // Fall back to basic syntax analysis if symbol not found
            return calculateFromSyntax(for: detectedType)
        }

        // 2. Get members (methods and properties)
        let members = try await queryMembers(of: classUSR)

        let methods = members.filter {
            $0.symbol.kind == .instanceMethod || $0.symbol.kind == .constructor
        }
        let properties = members.filter { $0.symbol.kind == .instanceProperty }

        // Early returns
        if methods.isEmpty { return 0 }
        if methods.count == 1 { return properties.isEmpty ? 0 : 1 }
        if properties.isEmpty { return 0 }

        // 3. Detect properties accessed by each method
        var methodToProperties: [String: Set<String>] = [:]

        for method in methods {
            let accessedProperties = try await findAccessedProperties(
                methodUSR: method.symbol.usr,
                properties: properties
            )
            methodToProperties[method.symbol.name] = accessedProperties
        }

        // 4. Detect method call relationships
        var methodCalls: [(String, String)] = []

        for method in methods {
            let calledMethods = try await findCalledMethods(
                methodUSR: method.symbol.usr,
                allMethods: methods
            )
            for called in calledMethods {
                methodCalls.append((method.symbol.name, called))
            }
        }

        // 5. Calculate connected components using Union-Find
        return calculateConnectedComponents(
            methods: methods.map(\.symbol.name),
            methodToProperties: methodToProperties,
            methodCalls: methodCalls
        )
    }

    // MARK: - IndexStore-DB Integration

    /// Searches for USR of class/struct/actor
    private func findUSR(for name: String, kind: IndexSymbolKind) async throws -> String? {
        return try await withCheckedThrowingContinuation { continuation in
            var foundUSR: String? = nil

            indexStoreDB.forEachCanonicalSymbolOccurrence(
                containing: name,
                anchorStart: false,
                anchorEnd: false,
                subsequence: false,
                ignoreCase: false
            ) { occurrence in
                if occurrence.symbol.name == name && occurrence.symbol.kind == kind {
                    foundUSR = occurrence.symbol.usr
                    return false  // Stop search
                }
                return true  // Continue search
            }

            continuation.resume(returning: foundUSR)
        }
    }

    /// Gets members of class/struct/actor
    private func queryMembers(of classUSR: String) async throws -> [SymbolOccurrence] {
        var members: [SymbolOccurrence] = []

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            indexStoreDB.forEachRelatedSymbolOccurrence(
                byUSR: classUSR,
                roles: .childOf
            ) { occurrence in
                members.append(occurrence)
                return true  // Continue search
            }
            continuation.resume()
        }

        return members
    }

    /// Detects properties accessed by a method
    private func findAccessedProperties(
        methodUSR: String,
        properties: [SymbolOccurrence]
    ) async throws -> Set<String> {
        var accessedProperties: Set<String> = []

        for property in properties {
            // Search for references to property
            let hasReference = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Bool, Error>) in
                var found = false

                indexStoreDB.forEachSymbolOccurrence(
                    byUSR: property.symbol.usr,
                    roles: .reference
                ) { occurrence in
                    // Check if reference is within the method
                    if occurrence.relations.contains(where: {
                        $0.symbol.usr == methodUSR && $0.roles.contains(.containedBy)
                    }) {
                        found = true
                        return false  // Stop search
                    }
                    return true  // Continue search
                }

                continuation.resume(returning: found)
            }

            if hasReference {
                accessedProperties.insert(property.symbol.name)
            }
        }

        return accessedProperties
    }

    /// Detects other methods called by a method
    private func findCalledMethods(
        methodUSR: String,
        allMethods: [SymbolOccurrence]
    ) async throws -> Set<String> {
        var calledMethods: Set<String> = []

        for targetMethod in allMethods {
            if targetMethod.symbol.usr == methodUSR { continue }

            // Search for method calls
            let isCalled = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Bool, Error>) in
                var found = false

                indexStoreDB.forEachSymbolOccurrence(
                    byUSR: targetMethod.symbol.usr,
                    roles: .call
                ) { occurrence in
                    // Check if caller is the target method
                    if occurrence.relations.contains(where: {
                        $0.symbol.usr == methodUSR && $0.roles.contains(.containedBy)
                    }) {
                        found = true
                        return false  // Stop search
                    }
                    return true  // Continue search
                }

                continuation.resume(returning: found)
            }

            if isCalled {
                calledMethods.insert(targetMethod.symbol.name)
            }
        }

        return calledMethods
    }

    // MARK: - Connected Components Calculation

    /// Calculates connected components using Union-Find
    private func calculateConnectedComponents(
        methods: [String],
        methodToProperties: [String: Set<String>],
        methodCalls: [(String, String)]
    ) -> Int {
        let uf = UnionFind(elements: methods)

        // Edge 1: Shared property access
        for (methodA, propertiesA) in methodToProperties {
            for (methodB, propertiesB) in methodToProperties {
                if methodA == methodB { continue }
                if !propertiesA.intersection(propertiesB).isEmpty {
                    uf.union(methodA, methodB)
                }
            }
        }

        // Edge 2: Method call relationships
        for (caller, callee) in methodCalls {
            uf.union(caller, callee)
        }

        return uf.componentCount()
    }

    // MARK: - Syntax Fallback

    /// Basic syntax analysis when symbol not found in IndexStore-DB
    private func calculateFromSyntax(for detectedType: DetectedNominal) -> Int {
        let (methods, properties) = extractMembersFromSyntax(detectedType.members)

        if methods.isEmpty { return 0 }
        if methods.count == 1 { return properties.isEmpty ? 0 : 1 }
        if properties.isEmpty { return 0 }

        let methodToProperties = extractPropertyAccessFromSyntax(
            methods: methods,
            properties: properties
        )

        let methodCalls = extractMethodCallsFromSyntax(methods: methods)

        return calculateConnectedComponents(
            methods: methods.map(\.name),
            methodToProperties: methodToProperties,
            methodCalls: methodCalls
        )
    }

    private func extractMembersFromSyntax(
        _ members: MemberBlockItemListSyntax
    ) -> (methods: [(name: String, body: CodeBlockSyntax?)], properties: [String]) {
        var methods: [(name: String, body: CodeBlockSyntax?)] = []
        var properties: [String] = []

        for member in members {
            if let method = extractMethod(from: member.decl) {
                methods.append(method)
            }
            properties.append(contentsOf: extractStoredProperties(from: member.decl))
        }

        return (methods, properties)
    }

    /// Checks for static modifier
    private func isStatic(_ modifiers: DeclModifierListSyntax) -> Bool {
        modifiers.contains { $0.name.text == "static" }
    }

    /// Extracts method (function, init, deinit) from DeclSyntax
    private func extractMethod(from decl: DeclSyntax) -> (name: String, body: CodeBlockSyntax?)? {
        if let functionDecl = decl.as(FunctionDeclSyntax.self) {
            guard !isStatic(functionDecl.modifiers) else { return nil }
            return (name: functionDecl.name.text, body: functionDecl.body)
        } else if let initDecl = decl.as(InitializerDeclSyntax.self) {
            return (name: "init", body: initDecl.body)
        } else if let deinitDecl = decl.as(DeinitializerDeclSyntax.self) {
            return (name: "deinit", body: deinitDecl.body)
        }
        return nil
    }

    /// Extracts stored properties from DeclSyntax
    private func extractStoredProperties(from decl: DeclSyntax) -> [String] {
        guard let variableDecl = decl.as(VariableDeclSyntax.self),
            !isStatic(variableDecl.modifiers)
        else { return [] }

        return variableDecl.bindings.compactMap { binding in
            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                binding.accessorBlock == nil
            else { return nil }
            return pattern.identifier.text
        }
    }

    private func extractPropertyAccessFromSyntax(
        methods: [(name: String, body: CodeBlockSyntax?)],
        properties: [String]
    ) -> [String: Set<String>] {
        var methodToProperties: [String: Set<String>] = [:]

        for method in methods {
            guard let body = method.body else { continue }

            var accessedProperties = Set<String>()
            let visitor = PropertyAccessVisitor(properties: properties)
            visitor.walk(body)
            accessedProperties.formUnion(visitor.accessedProperties)

            methodToProperties[method.name] = accessedProperties
        }

        return methodToProperties
    }

    private func extractMethodCallsFromSyntax(
        methods: [(name: String, body: CodeBlockSyntax?)]
    ) -> [(String, String)] {
        var methodCalls: [(String, String)] = []
        let methodNames = Set(methods.map(\.name))

        for method in methods {
            guard let body = method.body else { continue }

            let visitor = MethodCallVisitor(methodNames: methodNames)
            visitor.walk(body)

            for calledMethod in visitor.calledMethods {
                methodCalls.append((method.name, calledMethod))
            }
        }

        return methodCalls
    }

    // MARK: - Helper Methods

    /// Searches for libIndexStore path
    /// - Parameter toolchainPath: Optional toolchain path (e.g., ~/.local/share/swiftly/toolchains/swift-6.2).
    ///   On macOS, if nil, auto-detects from Xcode.
    ///   On Linux, this is required.
    /// - Returns: Path to libIndexStore.dylib (macOS) or libIndexStore.so (Linux)
    private static func findLibIndexStore(toolchainPath: URL?) throws -> String {
        #if os(Linux)
            let libName = "libIndexStore.so"
        #else
            let libName = "libIndexStore.dylib"
        #endif

        // If toolchainPath is provided, use it directly
        // Expected structure: <toolchainPath>/usr/lib/libIndexStore.{so,dylib}
        if let toolchainPath = toolchainPath {
            let libPath =
                toolchainPath
                .appendingPathComponent("usr")
                .appendingPathComponent("lib")
                .appendingPathComponent(libName)
            guard FileManager.default.fileExists(atPath: libPath.path) else {
                throw LCOMError.libIndexStoreNotFound(searchedPath: libPath.path)
            }
            return libPath.path
        }

        #if os(macOS)
            // Auto-detect Xcode toolchain on macOS
            return try findLibIndexStoreFromXcode()
        #else
            // On Linux, toolchainPath is required
            throw LCOMError.toolchainRequired
        #endif
    }

    #if os(macOS)
        /// Auto-detect libIndexStore from Xcode toolchain (macOS only)
        private static func findLibIndexStoreFromXcode() throws -> String {
            // Get Xcode toolchain path using xcrun
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
                throw LCOMError.toolchainRequired
            }

            // Infer toolchain lib directory from SDK path
            // /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
            // -> /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib
            let xcodeAppPath = sdkPath.components(separatedBy: "/Platforms/").first ?? ""
            let libPath =
                "\(xcodeAppPath)/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib"

            guard FileManager.default.fileExists(atPath: libPath) else {
                throw LCOMError.libIndexStoreNotFound(searchedPath: libPath)
            }

            return libPath
        }
    #endif
}

// MARK: - Syntax Visitors (Fallback)

/// Visitor for detecting property access
private class PropertyAccessVisitor: SyntaxVisitor {
    let properties: [String]
    var accessedProperties: Set<String> = []

    init(properties: [String]) {
        self.properties = properties
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        if let base = node.base?.as(DeclReferenceExprSyntax.self),
            base.baseName.text == "self"
        {
            let memberName = node.declName.baseName.text
            if properties.contains(memberName) {
                accessedProperties.insert(memberName)
            }
        }
        return .visitChildren
    }

    override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
        let name = node.baseName.text
        if properties.contains(name) {
            accessedProperties.insert(name)
        }
        return .visitChildren
    }
}

/// Visitor for detecting method calls
private class MethodCallVisitor: SyntaxVisitor {
    let methodNames: Set<String>
    var calledMethods: Set<String> = []

    init(methodNames: Set<String>) {
        self.methodNames = methodNames
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        if let memberAccess = node.calledExpression.as(MemberAccessExprSyntax.self) {
            let methodName = memberAccess.declName.baseName.text
            if methodNames.contains(methodName) {
                calledMethods.insert(methodName)
            }
        } else if let declRef = node.calledExpression.as(DeclReferenceExprSyntax.self) {
            let methodName = declRef.baseName.text
            if methodNames.contains(methodName) {
                calledMethods.insert(methodName)
            }
        }
        return .visitChildren
    }
}
