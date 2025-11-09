// Complex function with deeply nested if-else if-else chains
// Tests Issue #6: https://github.com/fummicc1/swift-complexity/issues/6
// Expected Cyclomatic Complexity: 14
// Expected Cognitive Complexity: 46

func processData(data: [String: Any]) -> String {
    guard let type = data["type"] as? String else {
        return "unknown"
    }

    if type == "user" {
        if let age = data["age"] as? Int {
            if age >= 18 {
                if let country = data["country"] as? String {
                    if country == "US" {
                        if let state = data["state"] as? String {
                            if state == "CA" {
                                return "adult_us_ca"
                            } else if state == "NY" {
                                return "adult_us_ny"
                            } else {
                                return "adult_us_other"
                            }
                        } else {
                            return "adult_us_no_state"
                        }
                    } else if country == "JP" {
                        return "adult_jp"
                    } else {
                        return "adult_other"
                    }
                } else {
                    return "adult_no_country"
                }
            } else {
                return "minor"
            }
        } else {
            return "no_age"
        }
    } else if type == "system" {
        if let priority = data["priority"] as? Int {
            if priority > 5 {
                return "high_priority_system"
            } else {
                return "low_priority_system"
            }
        } else {
            return "system_no_priority"
        }
    } else {
        return "unknown_type"
    }
}
