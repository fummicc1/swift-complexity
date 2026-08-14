// Suppression fixture for coupling analysis.
// Expected suppression sets collected by TypeRangeCollector:
//   CouplingSuppressedClass  [coupling]          (explicit metric name)
//   BareSuppressedEnum       [coupling]          (bare disable; lcom4 not applicable to enums)
//   BareSuppressedProtocol   [coupling]          (bare disable; lcom4 not applicable to protocols)
//   BareSuppressedStruct     [lcom4, coupling]   (bare disable suppresses all type-level metrics)
//   TypoedClass              []                  (unknown metric name fails closed)
//   extension entry          []                  (suppression on extensions is ignored by design)

// swift-complexity:disable coupling
class CouplingSuppressedClass {
    func a() {}
}

// swift-complexity:disable
enum BareSuppressedEnum {
    case one
}

// swift-complexity:disable
protocol BareSuppressedProtocol {
    func requirement()
}

// swift-complexity:disable
struct BareSuppressedStruct {
    var x: Int
}

// swift-complexity:disable couplig
class TypoedClass {
    func b() {}
}

// swift-complexity:disable coupling
extension CouplingSuppressedClass {
    func fromExtension() {}
}
