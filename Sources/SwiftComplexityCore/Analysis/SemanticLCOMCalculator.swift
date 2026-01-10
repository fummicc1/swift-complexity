import Foundation
import IndexStoreDB
import SwiftSyntax

// MARK: - Error Types

enum LCOMError: LocalizedError {
    case noMembersFound(className: String)
    case parsingFailed(className: String, underlying: Error)
    case indexStoreNotFound(projectRoot: String, hint: String)
    case indexDBInitializationFailed(underlying: Error)
    case symbolNotFound(symbolName: String, usr: String?)
    case queryTimeout(query: String)

    var errorDescription: String? {
        switch self {
        case .noMembersFound(let className):
            return "No members found in class '\(className)'"
        case .parsingFailed(let className, let error):
            return "Failed to parse class '\(className)': \(error.localizedDescription)"
        case .indexStoreNotFound(let projectRoot, let hint):
            return """
                Index store not found at '\(projectRoot)/.build/debug/index/store'.
                \(hint)
                """
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

/// 効率的な連結成分カウントのためのUnion-Find
class UnionFind {
    private var parent: [String: String] = [:]
    private var rank: [String: Int] = [:]

    init(elements: [String]) {
        for element in elements {
            parent[element] = element
            rank[element] = 0
        }
    }

    /// 要素のルートを検索（経路圧縮あり）
    func find(_ element: String) -> String {
        guard let p = parent[element] else { return element }
        if p != element {
            parent[element] = find(p)  // 経路圧縮
        }
        return parent[element]!
    }

    /// 2つの要素を同じ集合に統合
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

    /// 連結成分の数を計算
    func componentCount() -> Int {
        var roots = Set<String>()
        for element in parent.keys {
            roots.insert(find(element))
        }
        return roots.count
    }
}

// MARK: - Semantic LCOM Calculator

/// IndexStore-DB統合によるLCOM4計算エンジン（高精度：90-95%）
actor SemanticLCOMCalculator {
    private let indexStoreDB: IndexStoreDB
    private let projectRoot: URL

    init(projectRoot: URL) throws {
        self.projectRoot = projectRoot

        // IndexStore-DB初期化
        // .build/debugはアーキテクチャ固有のディレクトリへのシンボリックリンク
        let indexStorePath =
            projectRoot
            .appendingPathComponent(".build")
            .appendingPathComponent("debug")
            .appendingPathComponent("index")
            .appendingPathComponent("store")

        guard FileManager.default.fileExists(atPath: indexStorePath.path) else {
            throw LCOMError.indexStoreNotFound(
                projectRoot: projectRoot.path,
                hint: "Run 'swift build' first to generate the index"
            )
        }

        // libIndexStore.dylibのパスを取得（Xcodeツールチェーン）
        let libIndexStorePath = try Self.findLibIndexStore()

        self.indexStoreDB = try IndexStoreDB(
            storePath: indexStorePath.path,
            databasePath: NSTemporaryDirectory() + "lcom4-index.db",
            library: IndexStoreLibrary(dylibPath: libIndexStorePath)
        )
    }

    /// Nominal Type（class/struct/actor）のLCOM4値を計算
    func calculate(for detectedType: DetectedNominal) async throws -> Int {
        // 1. DetectedNominalからUSRを取得
        guard
            let classUSR = try await findUSR(
                for: detectedType.name,
                kind: detectedType.type.symbolKind
            )
        else {
            // シンボルが見つからない場合は基本的な構文解析にフォールバック
            return calculateFromSyntax(for: detectedType)
        }

        // 2. メンバー（メソッド・プロパティ）を取得
        let members = try await queryMembers(of: classUSR)

        let methods = members.filter {
            $0.symbol.kind == .instanceMethod || $0.symbol.kind == .constructor
        }
        let properties = members.filter { $0.symbol.kind == .instanceProperty }

        // 早期リターン
        if methods.isEmpty { return 0 }
        if methods.count == 1 { return properties.isEmpty ? 0 : 1 }
        if properties.isEmpty { return 0 }

        // 3. 各メソッドがアクセスするプロパティを検出
        var methodToProperties: [String: Set<String>] = [:]

        for method in methods {
            let accessedProperties = try await findAccessedProperties(
                methodUSR: method.symbol.usr,
                properties: properties
            )
            methodToProperties[method.symbol.name] = accessedProperties
        }

        // 4. メソッド呼び出し関係を検出
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

        // 5. Union-Findで連結成分を計算
        return calculateConnectedComponents(
            methods: methods.map(\.symbol.name),
            methodToProperties: methodToProperties,
            methodCalls: methodCalls
        )
    }

    // MARK: - IndexStore-DB Integration

    /// クラス/構造体/actorのUSRを検索
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
                    return false  // 検索終了
                }
                return true  // 検索続行
            }

            continuation.resume(returning: foundUSR)
        }
    }

    /// クラス/構造体/actorのメンバーを取得
    private func queryMembers(of classUSR: String) async throws -> [SymbolOccurrence] {
        var members: [SymbolOccurrence] = []

        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            indexStoreDB.forEachRelatedSymbolOccurrence(
                byUSR: classUSR,
                roles: .childOf
            ) { occurrence in
                members.append(occurrence)
                return true  // 検索続行
            }
            continuation.resume()
        }

        return members
    }

    /// メソッドがアクセスするプロパティを検出
    private func findAccessedProperties(
        methodUSR: String,
        properties: [SymbolOccurrence]
    ) async throws -> Set<String> {
        var accessedProperties: Set<String> = []

        for property in properties {
            // プロパティへの参照を検索
            let hasReference = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Bool, Error>) in
                var found = false

                indexStoreDB.forEachSymbolOccurrence(
                    byUSR: property.symbol.usr,
                    roles: .reference
                ) { occurrence in
                    // メソッド内の参照かチェック
                    if occurrence.relations.contains(where: {
                        $0.symbol.usr == methodUSR && $0.roles.contains(.containedBy)
                    }) {
                        found = true
                        return false  // 検索終了
                    }
                    return true  // 検索続行
                }

                continuation.resume(returning: found)
            }

            if hasReference {
                accessedProperties.insert(property.symbol.name)
            }
        }

        return accessedProperties
    }

    /// メソッドが呼び出す他のメソッドを検出
    private func findCalledMethods(
        methodUSR: String,
        allMethods: [SymbolOccurrence]
    ) async throws -> Set<String> {
        var calledMethods: Set<String> = []

        for targetMethod in allMethods {
            if targetMethod.symbol.usr == methodUSR { continue }

            // メソッド呼び出しを検索
            let isCalled = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Bool, Error>) in
                var found = false

                indexStoreDB.forEachSymbolOccurrence(
                    byUSR: targetMethod.symbol.usr,
                    roles: .call
                ) { occurrence in
                    // 呼び出し元が対象メソッドかチェック
                    if occurrence.relations.contains(where: {
                        $0.symbol.usr == methodUSR && $0.roles.contains(.containedBy)
                    }) {
                        found = true
                        return false  // 検索終了
                    }
                    return true  // 検索続行
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

    /// Union-Findで連結成分を計算
    private func calculateConnectedComponents(
        methods: [String],
        methodToProperties: [String: Set<String>],
        methodCalls: [(String, String)]
    ) -> Int {
        let uf = UnionFind(elements: methods)

        // エッジ1: 共通プロパティアクセス
        for (methodA, propertiesA) in methodToProperties {
            for (methodB, propertiesB) in methodToProperties {
                if methodA == methodB { continue }
                if !propertiesA.intersection(propertiesB).isEmpty {
                    uf.union(methodA, methodB)
                }
            }
        }

        // エッジ2: メソッド呼び出し関係
        for (caller, callee) in methodCalls {
            uf.union(caller, callee)
        }

        return uf.componentCount()
    }

    // MARK: - Syntax Fallback

    /// IndexStore-DBでシンボルが見つからない場合の基本的な構文解析
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

    /// static修飾子の有無をチェック
    private func isStatic(_ modifiers: DeclModifierListSyntax) -> Bool {
        modifiers.contains { $0.name.text == "static" }
    }

    /// DeclSyntaxからメソッド（関数、init、deinit）を抽出
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

    /// DeclSyntaxからストアドプロパティを抽出
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

    /// libIndexStore.dylibのパスを検索
    /// TODO: Linux対応 - Linuxでも動作するように修正が必要
    private static func findLibIndexStore() throws -> String {
        // xcrunでXcodeツールチェーンのパスを取得
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
            throw LCOMError.indexDBInitializationFailed(
                underlying: NSError(
                    domain: "SemanticLCOMCalculator", code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Failed to get SDK path from xcrun"
                    ])
            )
        }

        // SDKパスからツールチェーンのlibディレクトリを推測
        // /Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
        // -> /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib
        let xcodeAppPath = sdkPath.components(separatedBy: "/Platforms/").first ?? ""
        let libPath =
            "\(xcodeAppPath)/Toolchains/XcodeDefault.xctoolchain/usr/lib/libIndexStore.dylib"

        guard FileManager.default.fileExists(atPath: libPath) else {
            throw LCOMError.indexDBInitializationFailed(
                underlying: NSError(
                    domain: "SemanticLCOMCalculator", code: 2,
                    userInfo: [
                        NSLocalizedDescriptionKey: "libIndexStore.dylib not found at: \(libPath)"
                    ])
            )
        }

        return libPath
    }
}

// MARK: - Syntax Visitors (Fallback)

/// プロパティアクセスを検出するVisitor
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

/// メソッド呼び出しを検出するVisitor
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
