// Fixtures for type-level suppression comment detection (LCOM4).
// Suppression is parsed from the type declaration's leading trivia by
// NominalTypeDetector; the LCOM4 value itself is computed elsewhere.

// swift-complexity:disable
class BareSuppressedClass {
    var a: Int = 0
    var b: Int = 0
    func useA() { a += 1 }
    func useB() { b += 1 }
}

// swift-complexity:disable lcom4
struct Lcom4SuppressedStruct {
    var a: Int
    var b: Int
    func useA() -> Int { a }
    func useB() -> Int { b }
}

// A regular comment above a type must not trigger suppression.
actor NotSuppressedActor {
    var a: Int = 0
    var b: Int = 0
    func useA() { a += 1 }
    func useB() { b += 1 }
}

// A function-level metric name above a type suppresses nothing (fails closed).
// swift-complexity:disable cyclomatic
class WrongLevelMetricClass {
    var a: Int = 0
    var b: Int = 0
    func useA() { a += 1 }
    func useB() { b += 1 }
}

// A typo'd metric name suppresses nothing, unlike a bare disable.
// swift-complexity:disable lcom44
class TypoedMetricClass {
    var a: Int = 0
    var b: Int = 0
    func useA() { a += 1 }
    func useB() { b += 1 }
}
