// Function with else-if chain for cognitive complexity testing
// Expected Cyclomatic Complexity: 3 (base + if + else if)
// Expected Cognitive Complexity: 3 (if: +1, else if: +1, else: +1)
// Tests Issue #6: else-if should be treated as continuation, not nested

func checkValue(value: Int) -> String {
    if value == 1 {
        return "one"
    } else if value == 2 {
        return "two"
    } else {
        return "other"
    }
}
