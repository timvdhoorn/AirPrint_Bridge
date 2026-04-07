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

        func addUnique(_ code: String) {
            if !codes.contains(code) { codes.append(code) }
        }

        for line in trimmed.components(separatedBy: .newlines) {
            let line = line.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            // Match the bash patterns: check if the line contains the keyword
            // Values are parsed as everything after the first ':', split on spaces
            let values: [String] = {
                guard let colonRange = line.range(of: ":") else { return [] }
                return String(line[colonRange.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                    .map { $0.hasPrefix("*") ? String($0.dropFirst()) : $0 }
            }()

            if line.contains("ColorModel") {
                for value in values {
                    let lower = value.lowercased()
                    // Check AdobeRGB before RGB to avoid false match
                    if lower.contains("adobergb") {
                        addUnique("ADOBERGB24")
                        hasColor = true
                    } else if lower.contains("cmyk") {
                        addUnique("CMYK32")
                        hasColor = true
                    } else if lower.contains("rgb") || lower.contains("color") {
                        addUnique("SRGB24")
                        hasColor = true
                    } else if lower.contains("gray") || lower.contains("black") {
                        addUnique("W8")
                    }
                }
            } else if line.contains("cupsPrintQuality/Quality:") {
                for value in values {
                    let lower = value.lowercased()
                    if lower.contains("draft") {
                        addUnique("PQ1")
                    } else if lower.contains("normal") {
                        addUnique("PQ2")
                    } else if lower.contains("high") {
                        addUnique("PQ3")
                    } else if lower.contains("photo") || lower.contains("best") {
                        addUnique("PQ4")
                    }
                }
            } else if line.lowercased().contains("orientation") {
                for value in values {
                    let lower = value.lowercased()
                    // Check reverse variants BEFORE plain variants
                    if lower.contains("reverselandscape") {
                        addUnique("OR2")
                    } else if lower.contains("reverseportrait") {
                        addUnique("OR3")
                    } else if lower.contains("landscape") {
                        addUnique("OR1")
                    } else if lower.contains("portrait") || lower.contains("none") {
                        addUnique("OR0")
                    }
                }
            } else if line.contains("Duplex") {
                for value in values {
                    let lower = value.lowercased()
                    // Check specific duplex variants before generic none/off/simplex
                    if lower.contains("duplexnotumble") {
                        addUnique("DM2")
                        hasDuplex = true
                    } else if lower.contains("duplextumble") {
                        addUnique("DM3")
                        hasDuplex = true
                    } else if lower.contains("duplexmanual") {
                        addUnique("DM4")
                        hasDuplex = true
                    } else if lower.contains("none") || lower.contains("off") || lower.contains("simplex") {
                        addUnique("DM1")
                    }
                }
            } else if line.contains("PageSize/Media Size:") {
                // Bash unconditionally adds the hardcoded custom size when this line is found
                addUnique("MS_CUSTOM_100x150mm")
            } else if line.contains("MediaType/MediaType:") {
                for value in values {
                    let lower = value.lowercased()
                    if lower.contains("stationery") || lower.contains("any") {
                        addUnique("MT0")
                    } else if lower.contains("plain") {
                        addUnique("MT1")
                    } else if lower.contains("recycled") {
                        addUnique("MT2")
                    } else if lower.contains("transparency") {
                        addUnique("MT3")
                    } else if lower.contains("labels") {
                        addUnique("MT4")
                    } else if lower.contains("envelope") {
                        addUnique("MT5")
                    } else if lower.contains("photographic") {
                        addUnique("MT6")
                    } else if lower.contains("glossy") {
                        addUnique("MT7")
                    } else if lower.contains("matte") {
                        addUnique("MT8")
                    } else if lower.contains("cardstock") {
                        addUnique("MT9")
                    } else if lower.contains("letterhead") {
                        addUnique("MT10")
                    }
                }
            } else if line.contains("InputSlot/Media Source:") {
                for value in values {
                    let lower = value.lowercased()
                    if lower.contains("auto") {
                        addUnique("IS1")
                    } else if lower.contains("tray-1") {
                        addUnique("IS2")
                    } else if lower.contains("tray-2") {
                        addUnique("IS3")
                    } else if lower.contains("manual") {
                        addUnique("IS4")
                    } else if lower.contains("tray-3") {
                        addUnique("IS5")
                    } else if lower.contains("tray-4") {
                        addUnique("IS6")
                    } else if lower.contains("tray-5") {
                        addUnique("IS7")
                    } else if lower.contains("envelope") {
                        addUnique("IS8")
                    } else if lower.contains("multi") || lower.contains("multipurpose") {
                        addUnique("IS9")
                    } else if lower.contains("photo") {
                        addUnique("IS10")
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
}
