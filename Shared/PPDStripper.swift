import Foundation

enum PPDStripper {
    static func strip(ppd: String, widthPoints: Int, heightPoints: Int, sizeLabel: String) -> String {
        let key = "w\(widthPoints)h\(heightPoints)"
        let lines = ppd.components(separatedBy: "\n")
        var result: [String] = []
        var inPageSizeUI = false
        var inPageRegionUI = false
        var pageSizeInserted = false
        var pageRegionInserted = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Track PageSize UI block
            if trimmed.hasPrefix("*OpenUI *PageSize") {
                inPageSizeUI = true
                pageSizeInserted = false
                result.append(line)
                continue
            }
            if trimmed.hasPrefix("*CloseUI: *PageSize") {
                inPageSizeUI = false
                result.append(line)
                continue
            }

            // Track PageRegion UI block
            if trimmed.hasPrefix("*OpenUI *PageRegion") {
                inPageRegionUI = true
                pageRegionInserted = false
                result.append(line)
                continue
            }
            if trimmed.hasPrefix("*CloseUI: *PageRegion") {
                inPageRegionUI = false
                result.append(line)
                continue
            }

            // Inside PageSize block
            if inPageSizeUI {
                if trimmed.hasPrefix("*DefaultPageSize:") {
                    result.append("*DefaultPageSize: \(key)")
                } else if trimmed.hasPrefix("*PageSize ") {
                    if !pageSizeInserted {
                        result.append(pageSizeLine(key: key, sizeLabel: sizeLabel, width: widthPoints, height: heightPoints))
                        pageSizeInserted = true
                    }
                    // skip all original PageSize entries
                }
                continue
            }

            // Inside PageRegion block
            if inPageRegionUI {
                if trimmed.hasPrefix("*DefaultPageRegion:") {
                    result.append("*DefaultPageRegion: \(key)")
                } else if trimmed.hasPrefix("*PageRegion ") {
                    if !pageRegionInserted {
                        result.append(pageRegionLine(key: key, sizeLabel: sizeLabel, width: widthPoints, height: heightPoints))
                        pageRegionInserted = true
                    }
                    // skip all original PageRegion entries
                }
                continue
            }

            // DefaultImageableArea
            if trimmed.hasPrefix("*DefaultImageableArea:") {
                result.append("*DefaultImageableArea: \(key)")
                continue
            }

            // ImageableArea entries (not Default)
            if trimmed.hasPrefix("*ImageableArea ") {
                // Replace all with single entry (insert once, skip rest)
                if !result.contains(where: { $0.hasPrefix("*ImageableArea \(key)") }) {
                    result.append(imageableAreaLine(key: key, sizeLabel: sizeLabel, width: widthPoints, height: heightPoints))
                }
                continue
            }

            // DefaultPaperDimension
            if trimmed.hasPrefix("*DefaultPaperDimension:") {
                result.append("*DefaultPaperDimension: \(key)")
                continue
            }

            // PaperDimension entries (not Default)
            if trimmed.hasPrefix("*PaperDimension ") {
                if !result.contains(where: { $0.hasPrefix("*PaperDimension \(key)") }) {
                    result.append(paperDimensionLine(key: key, sizeLabel: sizeLabel, width: widthPoints, height: heightPoints))
                }
                continue
            }

            // CustomPageSize True -> False
            if trimmed.hasPrefix("*CustomPageSize True:") {
                let newLine = line.replacingOccurrences(of: "*CustomPageSize True:", with: "*CustomPageSize False:")
                result.append(newLine)
                continue
            }

            // Remove ParamCustomPageSize lines
            if trimmed.hasPrefix("*ParamCustomPageSize ") {
                continue
            }

            result.append(line)
        }

        return result.joined(separator: "\n")
    }

    // MARK: - Line Builders

    private static func pageSizeLine(key: String, sizeLabel: String, width: Int, height: Int) -> String {
        "*PageSize \(key)/\(sizeLabel): \"<</PageSize[\(width) \(height)]/ImagingBBox null>>setpagedevice\""
    }

    private static func pageRegionLine(key: String, sizeLabel: String, width: Int, height: Int) -> String {
        "*PageRegion \(key)/\(sizeLabel): \"<</PageSize[\(width) \(height)]/ImagingBBox null>>setpagedevice\""
    }

    private static func imageableAreaLine(key: String, sizeLabel: String, width: Int, height: Int) -> String {
        "*ImageableArea \(key)/\(sizeLabel): \"0 0 \(width) \(height)\""
    }

    private static func paperDimensionLine(key: String, sizeLabel: String, width: Int, height: Int) -> String {
        "*PaperDimension \(key)/\(sizeLabel): \"\(width) \(height)\""
    }
}
