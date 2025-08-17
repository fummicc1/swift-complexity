// Very complex function for performance testing
// Multiple levels of nesting to test complexity calculation performance
// Expected high complexity values

func veryComplexFunction(a: Int, b: Int, c: Int, d: Int) -> String {
  if a > 0 {
    if b > 0 {
      if c > 0 {
        if d > 0 {
          return "All positive"
        } else {
          return "D not positive"
        }
      } else {
        return "C not positive"
      }
    } else {
      return "B not positive"
    }
  } else {
    return "A not positive"
  }
}
