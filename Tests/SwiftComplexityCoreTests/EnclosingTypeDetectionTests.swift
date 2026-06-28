import SwiftParser
import SwiftSyntax
import Testing

@testable import SwiftComplexityCore

@Suite("Enclosing type detection")
struct EnclosingTypeDetectionTests {

    /// Parses `source` and returns detected functions keyed by name.
    private func detect(_ source: String) -> [String: DetectedFunction] {
        let sourceFile = Parser.parse(source: source)
        let detector = FunctionDetector(viewMode: .sourceAccurate)
        let functions = detector.detectFunctions(in: sourceFile)
        return Dictionary(functions.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
    }

    @Test("Method in a class reports the class name")
    func classMethod() {
        let functions = detect(
            """
            class UserRepository {
                func fetch() {}
            }
            """)
        #expect(functions["fetch"]?.enclosingTypeName == "UserRepository")
    }

    @Test("Method in a struct reports the struct name")
    func structMethod() {
        let functions = detect(
            """
            struct ToiletUseCase {
                func run() {}
            }
            """)
        #expect(functions["run"]?.enclosingTypeName == "ToiletUseCase")
    }

    @Test("Method in an enum reports the enum name")
    func enumMethod() {
        let functions = detect(
            """
            enum Router {
                func navigate() {}
            }
            """)
        #expect(functions["navigate"]?.enclosingTypeName == "Router")
    }

    @Test("Method in an actor reports the actor name")
    func actorMethod() {
        let functions = detect(
            """
            actor SessionStore {
                func save() {}
            }
            """)
        #expect(functions["save"]?.enclosingTypeName == "SessionStore")
    }

    @Test("Method in an extension reports the extended type")
    func extensionMethod() {
        let functions = detect(
            """
            extension UserClient {
                func login() {}
            }
            """)
        #expect(functions["login"]?.enclosingTypeName == "UserClient")
    }

    @Test("Free function has no enclosing type")
    func freeFunction() {
        let functions = detect("func globalHelper() {}")
        #expect(functions["globalHelper"] != nil)
        #expect(functions["globalHelper"]?.enclosingTypeName == nil)
    }

    @Test("Nested type uses the nearest enclosing type")
    func nestedType() {
        let functions = detect(
            """
            struct Outer {
                struct Inner {
                    func work() {}
                }
            }
            """)
        #expect(functions["work"]?.enclosingTypeName == "Inner")
    }

    @Test("Initializer reports its enclosing type")
    func initializer() {
        let functions = detect(
            """
            class PaymentRepository {
                init() {}
            }
            """)
        #expect(functions["init"]?.enclosingTypeName == "PaymentRepository")
    }

    @Test("Computed property accessor reports its enclosing type")
    func computedProperty() {
        let functions = detect(
            """
            struct AccountRepository {
                var balance: Int { 0 }
            }
            """)
        #expect(functions["balance"]?.enclosingTypeName == "AccountRepository")
    }
}
