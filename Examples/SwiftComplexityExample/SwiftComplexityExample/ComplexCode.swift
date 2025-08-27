import Foundation

// MARK: - Low Complexity (Below Threshold)

/// Complexity: Cyclomatic 1, Cognitive 1
func simpleFunction() -> Int {
    return 42
}

/// Complexity: Cyclomatic 2, Cognitive 2
func lowComplexityFunction(value: Int) -> String {
    if value > 0 {
        return "positive"
    } else {
        return "zero or negative"
    }
}

// MARK: - Medium Complexity (Near Threshold)

/// Complexity: Cyclomatic 4, Cognitive 6
func mediumComplexityFunction(score: Int) -> String {
    if score >= 90 {
        return "A"
    } else if score >= 80 {
        return "B" 
    } else if score >= 70 {
        return "C"
    } else {
        return "F"
    }
}

/// Complexity: Cyclomatic 5, Cognitive 7
func loopWithCondition(items: [Int]) -> [Int] {
    var result: [Int] = []
    
    for item in items {
        if item > 0 {
            if item % 2 == 0 {
                result.append(item * 2)
            } else {
                result.append(item * 3)
            }
        }
    }
    
    return result
}

// MARK: - High Complexity (Clearly Above Threshold)

/// Complexity: Cyclomatic 12, Cognitive 18 (Very High)
func veryComplexFunction(data: [String: Any]) -> String {
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

/// Complexity: Cyclomatic 15, Cognitive 22 (Extremely High)
func extremelyComplexFunction(input: String, options: [String: Bool]) -> (result: String, success: Bool) {
    var result = ""
    var success = false
    
    // Input validation
    if input.isEmpty {
        return ("empty_input", false)
    }
    
    // Options processing
    if let processSpaces = options["processSpaces"], processSpaces {
        if input.contains(" ") {
            if let trimSpaces = options["trimSpaces"], trimSpaces {
                result = input.trimmingCharacters(in: .whitespaces)
                if result.isEmpty {
                    return ("only_spaces", false)
                }
            } else {
                result = input.replacingOccurrences(of: " ", with: "_")
            }
        } else {
            result = input
        }
    } else {
        result = input
    }
    
    // Character count validation
    if result.count < 3 {
        if let allowShort = options["allowShort"], allowShort {
            success = true
        } else {
            return ("too_short", false)
        }
    } else if result.count > 50 {
        if let truncateLong = options["truncateLong"], truncateLong {
            result = String(result.prefix(50))
            success = true
        } else {
            return ("too_long", false)
        }
    } else {
        success = true
    }
    
    // Special character processing
    if let processSpecial = options["processSpecial"], processSpecial {
        if result.contains("@") {
            if let emailMode = options["emailMode"], emailMode {
                if result.contains("@") && result.contains(".") {
                    result = "email_format"
                    success = true
                } else {
                    return ("invalid_email", false)
                }
            } else {
                result = result.replacingOccurrences(of: "@", with: "_at_")
            }
        }
        
        if result.contains("#") {
            if let hashtagMode = options["hashtagMode"], hashtagMode {
                result = result.replacingOccurrences(of: "#", with: "hashtag_")
            } else {
                result = result.replacingOccurrences(of: "#", with: "_hash_")
            }
        }
    }
    
    // Final validation
    if result.isEmpty {
        return ("empty_result", false)
    }
    
    if success {
        if let validateFinal = options["validateFinal"], validateFinal {
            if result.count % 2 == 0 {
                return (result.uppercased(), true)
            } else {
                return (result.lowercased(), true)
            }
        } else {
            return (result, true)
        }
    } else {
        return ("processing_failed", false)
    }
}
