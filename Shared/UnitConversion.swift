import Foundation

enum UnitConversion {
    private static let pointsPerMm: Double = 2.8346

    static func mmToPoints(_ mm: Int) -> Int {
        Int((Double(mm) * pointsPerMm).rounded())
    }

    static func pointsToMm(_ points: Int) -> Int {
        Int((Double(points) / pointsPerMm).rounded())
    }
}
