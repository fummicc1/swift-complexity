// Fixtures for inline suppression comment detection.
// Every function below has cyclomatic complexity 3 (base 1 + 2 sibling if
// statements) and cognitive complexity 2 (2 sibling ifs, no nesting bonus).

// swift-complexity:disable
func fullySuppressed(a: Int, b: Int) {
    if a > 0 {
        print("a")
    }
    if b > 0 {
        print("b")
    }
}

// swift-complexity:disable cyclomatic
func cyclomaticOnlySuppressed(a: Int, b: Int) {
    if a > 0 {
        print("a")
    }
    if b > 0 {
        print("b")
    }
}

/// Doc comments are never mistaken for a directive, even when phrased
/// similarly and placed directly above the declaration.
// swift-complexity:disable cognitive
func cognitiveOnlySuppressed(a: Int, b: Int) {
    if a > 0 {
        print("a")
    }
    if b > 0 {
        print("b")
    }
}

// This is an unrelated comment that happens to precede a complex function.
func notSuppressed(a: Int, b: Int) {
    if a > 0 {
        print("a")
    }
    if b > 0 {
        print("b")
    }
}

// A typo'd metric name suppresses nothing (fails closed), unlike a bare
// disable which would suppress everything.
// swift-complexity:disable cyclomattic
func typoedMetricNotSuppressed(a: Int, b: Int) {
    if a > 0 {
        print("a")
    }
    if b > 0 {
        print("b")
    }
}

struct SuppressedComputedProperty {
    // swift-complexity:disable
    var isValid: Bool {
        if true {
            if true {
                return true
            }
        }
        return false
    }
}
