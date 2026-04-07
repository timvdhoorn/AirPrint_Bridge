import Foundation

struct URFResult {
    let urf: String
    let hasColor: Bool
    let hasDuplex: Bool
}

enum URFGenerator {

    static func generate(from lpoptions: String) -> URFResult {
        let trimmed = lpoptions.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return URFResult(urf: "none", hasColor: false, hasDuplex: false)
        }

        var codes: [String] = []
        var hasColor = false
        var hasDuplex = false

        for line in trimmed.components(separatedBy: .newlines) {
            let line = line.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, let colonRange = line.range(of: ":") else { continue }

            let key = String(line[line.startIndex..<colonRange.lowerBound])
                .lowercased()
            let valuesPart = String(line[colonRange.upperBound...])
                .trimmingCharacters(in: .whitespaces)

            let values = valuesPart
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }
                .map { $0.hasPrefix("*") ? String($0.dropFirst()) : $0 }

            if key.hasPrefix("colormodel") {
                for value in values {
                    if let code = colorCode(for: value) {
                        if !codes.contains(code) { codes.append(code) }
                        if code == "SRGB24" { hasColor = true }
                    }
                }
            } else if key.hasPrefix("cupsprintquality") || key.hasPrefix("quality") {
                for value in values {
                    if let code = qualityCode(for: value) {
                        if !codes.contains(code) { codes.append(code) }
                    }
                }
            } else if key.hasPrefix("orientation") {
                for value in values {
                    if let code = orientationCode(for: value) {
                        if !codes.contains(code) { codes.append(code) }
                    }
                }
            } else if key.hasPrefix("duplex") {
                for value in values {
                    if let code = duplexCode(for: value) {
                        if !codes.contains(code) { codes.append(code) }
                        if code == "DM2" { hasDuplex = true }
                    }
                }
            } else if key.hasPrefix("pagesize") || key.hasPrefix("media size") {
                for value in values {
                    let code = mediaSizeCode(for: value)
                    if !codes.contains(code) { codes.append(code) }
                }
            } else if key.hasPrefix("mediatype") {
                for value in values {
                    if let code = mediaTypeCode(for: value) {
                        if !codes.contains(code) { codes.append(code) }
                    }
                }
            } else if key.hasPrefix("inputslot") || key.hasPrefix("media source") {
                for value in values {
                    if let code = inputSlotCode(for: value) {
                        if !codes.contains(code) { codes.append(code) }
                    }
                }
            }
        }

        if codes.isEmpty {
            return URFResult(urf: "none", hasColor: false, hasDuplex: false)
        }

        let urf = "V1.4," + codes.joined(separator: ",")
        return URFResult(urf: urf, hasColor: hasColor, hasDuplex: hasDuplex)
    }

    // MARK: - Private helpers

    private static func colorCode(for value: String) -> String? {
        let lower = value.lowercased()
        if lower == "gray" || lower == "black" { return "W8" }
        if lower == "adobergb" { return "ADOBERGB24" }
        if lower == "cmyk" { return "CMYK32" }
        if lower.contains("rgb") || lower.contains("color") { return "SRGB24" }
        return nil
    }

    private static func qualityCode(for value: String) -> String? {
        switch value.lowercased() {
        case "draft": return "PQ1"
        case "normal": return "PQ2"
        case "high": return "PQ3"
        case "photo", "best": return "PQ4"
        default: return nil
        }
    }

    private static func orientationCode(for value: String) -> String? {
        // Check reverse variants before plain variants to avoid substring match
        let lower = value.lowercased()
        if lower.contains("reverselandscape") { return "OR2" }
        if lower.contains("reverseportrait") { return "OR3" }
        if lower.contains("landscape") { return "OR1" }
        if lower == "portrait" || lower == "none" { return "OR0" }
        return nil
    }

    private static func duplexCode(for value: String) -> String? {
        let lower = value.lowercased()
        if lower == "none" || lower == "off" || lower == "simplex" { return "DM1" }
        if lower == "duplexnotumble" { return "DM2" }
        if lower == "duplextumble" { return "DM3" }
        if lower == "duplexmanual" { return "DM4" }
        return nil
    }

    private static func mediaSizeCode(for value: String) -> String {
        // Parse wNNNhNNN (points) and convert to mm
        if value.lowercased().hasPrefix("w"),
           let xRange = value.range(of: "h", options: .caseInsensitive),
           let widthPoints = Int(value[value.index(after: value.startIndex)..<xRange.lowerBound]),
           let heightPoints = Int(value[xRange.upperBound...]) {
            let widthMm = UnitConversion.pointsToMm(widthPoints)
            let heightMm = UnitConversion.pointsToMm(heightPoints)
            return "MS_CUSTOM_\(widthMm)x\(heightMm)mm"
        }
        return "MS_CUSTOM_\(value)"
    }

    private static func mediaTypeCode(for value: String) -> String? {
        switch value.lowercased() {
        case "stationery", "any": return "MT0"
        case "plain": return "MT1"
        case "recycled": return "MT2"
        case "transparency": return "MT3"
        case "labels": return "MT4"
        case "envelope": return "MT5"
        case "photographic": return "MT6"
        case "glossy": return "MT7"
        case "matte": return "MT8"
        case "cardstock": return "MT9"
        case "letterhead": return "MT10"
        default: return nil
        }
    }

    private static func inputSlotCode(for value: String) -> String? {
        switch value.lowercased() {
        case "auto": return "IS1"
        case "tray-1", "tray1": return "IS2"
        case "tray-2", "tray2": return "IS3"
        case "manual": return "IS4"
        default: return nil
        }
    }
}
