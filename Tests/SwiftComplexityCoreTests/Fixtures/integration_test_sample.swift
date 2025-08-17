// Integration test sample with multiple functions
// Expected: 2 functions detected
// simpleFunction: Cyclomatic=1, Cognitive=0
// complexFunction: Cyclomatic=3, Cognitive varies

func simpleFunction() -> String {
  return "Hello, World!"
}

func complexFunction(number: Int) -> String {
  if number > 0 {
    if number > 10 {
      return "Large"
    } else {
      return "Small positive"
    }
  } else {
    return "Not positive"
  }
}
