// Fixture for TypeRangeCollector / coupling attribution tests.
// Expected type-range entries (name, kind):
//   ServiceProtocol   protocol
//   Outer             struct
//   Outer.Inner       struct   (nested -> dotted name)
//   MyActor           actor    (must not be reported as class)
//   Outer             ext      (extension resolves to extended type "Outer")
//   Payload           enum
// The typealias is intentionally NOT an entry: coupling excludes typealiases.

protocol ServiceProtocol {
    func run()
}

struct Outer {
    struct Inner {
        let parent: Int
    }

    func use(_ value: Inner) -> Inner {
        value
    }
}

actor MyActor: ServiceProtocol {
    func run() {}
}

extension Outer {
    func extra() -> Int { 1 }
}

enum Payload {
    case wrapped(Outer)
    case empty
}

typealias OuterAlias = Outer
