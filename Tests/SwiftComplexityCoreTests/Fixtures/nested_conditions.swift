// Function with nested if-else conditions
// Expected Cyclomatic Complexity: 3 (base + if + nested if + else implied)
// Expected Cognitive Complexity: 3 (outer if: 1, inner if: 1+1 nesting = 2, total = 3)

func complexFunction(a: Int, b: Int) {
    if a > 0 {
        if b > 0 {
            print("Both positive")
        } else {
            print("A positive, B not")
        }
    } else {
        print("A not positive")
    }
}
