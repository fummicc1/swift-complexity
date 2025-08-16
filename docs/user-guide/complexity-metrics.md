# Complexity Metrics

This document provides detailed explanations of the complexity metrics supported by swift-complexity.

## Cyclomatic Complexity

Cyclomatic complexity measures the number of linearly independent paths through a program's source code. It quantifies the complexity of a program by counting the number of decision points.

### Calculation Method

The cyclomatic complexity is calculated as the number of decision points plus 1:

**Base complexity: 1 (entry point)**

### Decision Points

The following Swift language constructs contribute to cyclomatic complexity:

#### Conditional Statements
- `if` statements: +1 for each `if`
- `guard` statements: +1 for each `guard`
- `else if` clauses: +1 for each `else if`
- Ternary operators (`? :`): +1

#### Loop Statements
- `while` loops: +1
- `for` loops: +1
- `repeat-while` loops: +1

#### Switch Statements
- `switch` statements: +1 for the switch itself
- Each `case` clause: +1 (including `default`)

#### Logical Operators
- `&&` (logical AND): +1 for each occurrence
- `||` (logical OR): +1 for each occurrence

#### Exception Handling
- `catch` blocks: +1 for each `catch`

### Example

```swift
func calculateDiscount(amount: Double, customerType: String) -> Double {
    // Base complexity: 1
    
    if amount > 1000 {  // +1
        if customerType == "premium" {  // +1
            return amount * 0.15
        } else if customerType == "gold" {  // +1
            return amount * 0.10
        } else {
            return amount * 0.05
        }
    } else if amount > 500 {  // +1
        return amount * 0.03
    }
    
    return 0
}
// Total cyclomatic complexity: 5
```

## Cognitive Complexity

Cognitive complexity measures how difficult the code is for humans to understand. Unlike cyclomatic complexity, it takes into account the nesting level of control structures, as nested code is harder to understand.

### Calculation Method

Cognitive complexity is calculated by assigning points for:
1. Control flow structures
2. Nesting increments
3. Logical operator sequences

### Scoring Rules

#### Basic Control Structures (+1 each)
- `if`, `else if`, `else`
- `switch`, `case`
- `for`, `while`, `repeat-while`
- `guard`
- `catch`
- `break`, `continue` (when jumping to a label)

#### Nesting Increment
For each level of nesting inside the following structures:
- `if`, `else if`, `else`
- `switch`, `case`
- `for`, `while`, `repeat-while`
- `catch`

The nesting increment is added to the base score of nested control structures.

#### Logical Operator Sequences
- First `&&` or `||` in a sequence: +0
- Each additional `&&` or `||` in the same sequence: +1

### Nesting Examples

```swift
func processData(items: [String]) {
    for item in items {  // +1 (base)
        if item.isEmpty {  // +1 (base) + 1 (nesting) = +2
            continue
        }
        
        if item.count > 10 {  // +1 (base) + 1 (nesting) = +2
            for char in item {  // +1 (base) + 1 (nesting) = +2
                if char.isNumber {  // +1 (base) + 2 (nesting) = +3
                    // Process number
                }
            }
        }
    }
}
// Total cognitive complexity: 10
```

### Logical Operators Example

```swift
func validateUser(name: String, age: Int, email: String) -> Bool {
    // First condition in sequence doesn't add to cognitive complexity
    if !name.isEmpty && age >= 18 && email.contains("@") {  // +1 (if) + 0 (first &&) + 1 (second &&) + 1 (third &&) = +3
        return true
    }
    return false
}
// Total cognitive complexity: 3
```

## Comparison

| Aspect | Cyclomatic Complexity | Cognitive Complexity |
|--------|----------------------|---------------------|
| **Purpose** | Measure testing complexity | Measure readability |
| **Nesting** | Not considered | Heavily weighted |
| **Logical Operators** | Each operator +1 | Sequences weighted |
| **Best for** | Test case planning | Code review |

## Interpretation Guidelines

### Cyclomatic Complexity Thresholds
- **1-10**: Simple, easy to test
- **11-20**: Moderate complexity, acceptable
- **21-50**: Complex, should be simplified
- **50+**: Very complex, refactor immediately

### Cognitive Complexity Thresholds
- **1-5**: Very readable
- **6-10**: Readable
- **11-15**: Moderate difficulty
- **16-25**: Hard to understand
- **25+**: Very hard to understand, refactor

## Implementation Notes

### Swift-Specific Considerations

#### Optional Chaining
Optional chaining (`?.`) is not counted as it doesn't add control flow complexity.

#### Pattern Matching
Complex pattern matching in `switch` statements may have higher cognitive complexity due to nesting.

#### Closures
Closures are analyzed as separate units when they contain control flow.

#### Error Handling
- `try?` and `try!`: Not counted
- `do-catch` blocks: Counted normally
- `throws` functions: Not counted (complexity is in the caller)

### Limitations

1. **Cross-function complexity**: Metrics are calculated per function/method only
2. **Semantic complexity**: Does not consider algorithmic complexity
3. **Context ignorance**: Cannot distinguish between different types of complexity

## References

- [Cyclomatic Complexity - McCabe (1976)](https://www.literateprogramming.com/mccabe.pdf)
- [Cognitive Complexity - SonarSource](https://www.sonarsource.com/docs/CognitiveComplexity.pdf)
- [Swift Language Reference](https://docs.swift.org/swift-book/)