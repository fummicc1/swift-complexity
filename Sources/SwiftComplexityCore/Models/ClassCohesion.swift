import Foundation

/// Nominal Type種類（class/struct/actor）
public enum NominalType: String, Codable, Sendable {
    case `class`
    case `struct`
    case actor
}

/// 凝集度レベルの分類
public enum CohesionLevel: String, Codable, Sendable {
    case high  // LCOM4 = 0 or 1（理想）
    case moderate  // LCOM4 = 2（許容）
    case low  // LCOM4 >= 3（要リファクタリング）
}

/// クラス/構造体/actorの凝集度情報
public struct ClassCohesion: Codable, Hashable, Sendable {
    /// クラス/構造体/actor名
    public let name: String

    /// Nominal Type種類
    public let type: NominalType

    /// LCOM4値（連結成分の数）
    public let lcom4: Int

    /// メソッド数
    public let methodCount: Int

    /// プロパティ数
    public let propertyCount: Int

    /// ソースコード位置
    public let location: SourceLocation

    /// 凝集度レベル（計算プロパティ）
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

/// ファイル全体の凝集度サマリー
public struct CohesionSummary: Codable, Sendable {
    /// 分析されたクラス/構造体/actorの総数
    public let totalClasses: Int

    /// 平均LCOM4値
    public let averageLCOM4: Double

    /// 最大LCOM4値
    public let maxLCOM4: Int

    /// 凝集度が低いクラスの数（LCOM4 >= 3）
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
