import Foundation

struct PrinterConfig: Codable, Identifiable, Equatable {
    let name: String
    let widthMm: Int
    let heightMm: Int
    var enabled: Bool

    var id: String { name }

    var widthPoints: Int { UnitConversion.mmToPoints(widthMm) }
    var heightPoints: Int { UnitConversion.mmToPoints(heightMm) }
    var sizeLabel: String { "\(widthMm)x\(heightMm)" }
}
