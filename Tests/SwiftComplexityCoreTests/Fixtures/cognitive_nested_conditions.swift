// Function with nested conditions for cognitive complexity testing
// Expected Cyclomatic Complexity: 3 (base + if + nested if)
// Expected Cognitive Complexity: 3 (outer if: 1+0 nesting, inner if: 1+1 nesting, total = 3)

func nestedFunction(a: Int, b: Int) {
    if a > 0 {
        if b > 0 {
            print("Both positive")
        }
    }
}
