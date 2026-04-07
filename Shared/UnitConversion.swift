import Foundation

enum UnitConversion {
    private static let pointsPerMm: Double = 2.8346

    static func mmToPoints(_ mm: Int) -> Int {
        Int(ceil(Double(mm) * pointsPerMm))
    }

    static func pointsToMm(_ points: Int) -> Int {
        Int(floor(Double(points) / pointsPerMm))
    }
}
