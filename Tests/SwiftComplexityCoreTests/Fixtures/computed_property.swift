struct ComputedPropertyExample {
    // Shorthand computed property (implicit getter)
    // Expected: cyclomatic = 3 (2 if statements + 1 base), cognitive = 3 (2 if + 1 else)
    var shorthandGetter: Bool {
        let rand = Int.random(in: 0..<10)
        if rand == 0 {
            return true
        }
        if rand > 5 {
            return true
        } else {
            return false
        }
    }

    // Explicit get/set accessors
    // get: cyclomatic = 2 (1 if + 1 base), cognitive = 1
    // set: cyclomatic = 1 (base only), cognitive = 0
    private var _explicitProperty: String = ""
    var explicitProperty: String {
        get {
            if _explicitProperty.isEmpty {
                return "default"
            }
            return _explicitProperty
        }
        set {
            _explicitProperty = newValue
        }
    }

    // Property observer (didSet)
    // didSet: cyclomatic = 2 (1 if + 1 base), cognitive = 1
    var observedProperty: Int = 0 {
        didSet {
            if observedProperty < 0 {
                observedProperty = 0
            }
        }
    }
}
