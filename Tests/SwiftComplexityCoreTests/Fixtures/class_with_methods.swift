// Class with multiple methods for function detection testing
// Expected: 3 functions detected (init, method1, method2)
// Function names: init, method1, method2

class TestClass {
    init(value: Int) {
        self.value = value
    }

    func method1() {
        print("method1")
    }

    func method2() -> String {
        return "method2"
    }
}
