import Foundation

/// Nominal Type kind (class/struct/actor)
public enum NominalType: String, Codable, Sendable {
    case `class`
    case `struct`
    case actor
}

/// Classification of cohesion levels
public enum CohesionLevel: String, Codable, Sendable {
    case high  // LCOM4 = 0 or 1 (ideal)
    case moderate  // LCOM4 = 2 (acceptable)
    case low  // LCOM4 >= 3 (needs refactoring)
}

/// Cohesion information for class/struct/actor
public struct ClassCohesion: Codable, Hashable, Sendable {
    /// Class/struct/actor name
    public let name: String

    /// Nominal Type kind
    public let type: NominalType

    /// LCOM4 value (number of connected components)
    public let lcom4: Int

    /// Method count
    public let methodCount: Int

    /// Property count
    public let propertyCount: Int

    /// Source code location
    public let location: SourceLocation

    /// Cohesion level (computed property)
    public var cohesionLevel: CohesionLevel {
        switch lcom4 {
        case 0, 1:
            return .high
        case 2:
            return .moderate
        default:
            return .low
        }
    }

    public init(
        name: String,
        type: NominalType,
        lcom4: Int,
        methodCount: Int,
        propertyCount: Int,
        location: SourceLocation
    ) {
        self.name = name
        self.type = type
        self.lcom4 = lcom4
        self.methodCount = methodCount
        self.propertyCount = propertyCount
        self.location = location
    }
}

extension ClassCohesion: CustomStringConvertible {
    public var description: String {
        "\(name) (\(type.rawValue)): LCOM4=\(lcom4), cohesion=\(cohesionLevel.rawValue)"
    }
}

/// Cohesion summary for the entire file
public struct CohesionSummary: Codable, Sendable {
    /// Total number of analyzed classes/structs/actors
    public let totalClasses: Int

    /// Average LCOM4 value
    public let averageLCOM4: Double

    /// Maximum LCOM4 value
    public let maxLCOM4: Int

    /// Number of classes with low cohesion (LCOM4 >= 3)
    public let classesWithLowCohesion: Int

    public init(classes: [ClassCohesion]) {
        self.totalClasses = classes.count

        if classes.isEmpty {
            self.averageLCOM4 = 0.0
            self.maxLCOM4 = 0
            self.classesWithLowCohesion = 0
        } else {
            let lcom4Values = classes.map(\.lcom4)
            self.averageLCOM4 = Double(lcom4Values.reduce(0, +)) / Double(classes.count)
            self.maxLCOM4 = lcom4Values.max() ?? 0
            self.classesWithLowCohesion = classes.filter { $0.cohesionLevel == .low }.count
        }
    }
}

extension CohesionSummary: CustomStringConvertible {
    public var description: String {
        """
        Cohesion Summary:
          Total classes: \(totalClasses)
          Average LCOM4: \(String(format: "%.2f", averageLCOM4))
          Max LCOM4: \(maxLCOM4)
          Low cohesion classes: \(classesWithLowCohesion)
        """
    }
}
