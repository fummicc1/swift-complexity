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
- `if` statements: +1 for each condition (`if let a, b` has two conditions: +2)
- `guard` statements: +1 for each condition
- `else if` clauses: +1 for each condition
- Ternary operators (`? :`): +1

#### Loop Statements
- `while` loops: +1 for each condition
- `for` loops: +1, plus +1 for a `where` clause
- `repeat-while` loops: +1

#### Switch Statements
- Each `case` label: +1 (a label with several patterns, such as `case 1, 2:`, counts once)
- The `switch` itself and `default`: not counted

#### Logical Operators
- `&&` (logical AND): +1 for each occurrence
- `||` (logical OR): +1 for each occurrence
- `??` (nil-coalescing): +1 for each occurrence

#### Exception Handling
- `catch` blocks: +1 for each `catch`

#### Conditional Compilation
- `#if` / `#elseif` / `#else`: only one clause is compiled, so only the most complex clause counts

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
- `switch` (once for the whole statement; `case` labels add nothing)
- `for`, `while`, `repeat-while`
- `guard`
- `catch`
- Ternary operators (`? :`)

#### Nesting Increment
For each level of nesting inside the following structures:
- `if`, `else if`, `else`
- `switch`
- `for`, `while`, `repeat-while`
- `catch`

The nesting increment is added to the base score of nested `if`, `switch`, loop, `catch` and ternary structures. `else if` and `else` never receive it, and `guard` adds +1 without a nesting increment.

#### Conditional Compilation
- `#if` / `#elseif` / `#else`: only the most complex clause counts; the directive adds no nesting

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

#### Optional Chaining and Nil-Coalescing
Optional chaining (`?.`) is not counted as it doesn't add control flow complexity.

Nil-coalescing (`a ?? b`) is a branch, so it adds +1 to cyclomatic complexity. Following SonarSource's specification, it adds nothing to cognitive complexity.

#### Pattern Matching
Complex pattern matching in `switch` statements may have higher cognitive complexity due to nesting.

#### Closures and Nested Declarations
Closures count toward the function that contains them.

Nested functions, methods of local types, and local computed properties are reported as functions of their own, so their bodies are not added to the enclosing function.

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