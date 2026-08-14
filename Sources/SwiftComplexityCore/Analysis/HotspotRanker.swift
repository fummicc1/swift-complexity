import Foundation

/// One entry of the hotspot ranking: a complexity-violating function paired
/// with how widely its enclosing type is depended upon.
struct Hotspot: Sendable, Equatable {
    let function: FunctionComplexity
    let filePath: String
    /// Fan-in of the enclosing type; 0 when the type cannot be resolved
    /// (free functions, ambiguous names), which sinks the entry naturally.
    let typeFanIn: Int
}

/// Ranks complexity violations by the blast radius of their enclosing type.
///
/// Answers "which violation should be fixed first": a complex function inside
/// a high fan-in type is the riskiest code in the project. The order is a
/// plain lexicographic sort - (type fan-in desc, cognitive desc, cyclomatic
/// desc, name) - rather than a weighted score, so users can verify the
/// ranking by eye.
enum HotspotRanker {

    static func rank(
        results: [ComplexityResult],
        configuration: ThresholdConfiguration,
        fallbackThreshold: Int?,
        limit: Int = 10
    ) -> [Hotspot] {
        var fanInCandidates: [String: [(file: String, fanIn: Int)]] = [:]
        for result in results {
            for coupling in result.typeCouplings ?? [] {
                fanInCandidates[coupling.name, default: []].append(
                    (result.filePath, coupling.fanIn))
            }
        }

        /// Resolves a function's enclosing type to its fan-in. Coupling names
        /// are dotted for nested types while `enclosingTypeName` is simple,
        /// so suffix matches count too. Same-file candidates win; ambiguity
        /// without a same-file match resolves to 0 instead of guessing.
        func typeFanIn(enclosingTypeName: String?, file: String) -> Int {
            guard let name = enclosingTypeName else { return 0 }
            let matches = fanInCandidates.flatMap { candidateName, candidates in
                candidateName == name || candidateName.hasSuffix(".\(name)")
                    ? candidates : []
            }
            if matches.isEmpty { return 0 }
            let sameFile = matches.filter { $0.file == file }
            if sameFile.count == 1 { return sameFile[0].fanIn }
            return matches.count == 1 ? matches[0].fanIn : 0
        }

        var hotspots: [Hotspot] = []
        for result in results {
            for function in result.functions
            where configuration.isExceeded(function, fallback: fallbackThreshold) {
                hotspots.append(
                    Hotspot(
                        function: function,
                        filePath: result.filePath,
                        typeFanIn: typeFanIn(
                            enclosingTypeName: function.enclosingTypeName,
                            file: result.filePath)
                    ))
            }
        }

        return
            hotspots
            .sorted { lhs, rhs in
                if lhs.typeFanIn != rhs.typeFanIn { return lhs.typeFanIn > rhs.typeFanIn }
                if lhs.function.cognitiveComplexity != rhs.function.cognitiveComplexity {
                    return lhs.function.cognitiveComplexity > rhs.function.cognitiveComplexity
                }
                if lhs.function.cyclomaticComplexity != rhs.function.cyclomaticComplexity {
                    return lhs.function.cyclomaticComplexity > rhs.function.cyclomaticComplexity
                }
                return lhs.function.name < rhs.function.name
            }
            .prefix(limit)
            .map { $0 }
    }
}
