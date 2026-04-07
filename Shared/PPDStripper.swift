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
            // Fix 4: match on original line (not trimmed), using hasPrefix to mirror bash awk `^` anchoring

            // Track PageSize UI block — OpenUI
            if line.hasPrefix("*OpenUI *PageSize") {
                inPageSizeUI = true
                pageSizeInserted = false
                result.append(line)
                continue
            }

            // Track PageSize UI block — CloseUI
            // Fix 1: insert fallback entry before CloseUI if nothing was printed inside the block
            if line.hasPrefix("*CloseUI: *PageSize") {
                if inPageSizeUI && !pageSizeInserted {
                    result.append(pageSizeLine(key: key, sizeLabel: sizeLabel, width: widthPoints, height: heightPoints))
                    pageSizeInserted = true
                }
                inPageSizeUI = false
                result.append(line)
                continue
            }

            // Track PageRegion UI block — OpenUI
            if line.hasPrefix("*OpenUI *PageRegion") {
                inPageRegionUI = true
                pageRegionInserted = false
                result.append(line)
                continue
            }

            // Track PageRegion UI block — CloseUI
            // Fix 1: insert fallback entry before CloseUI if nothing was printed inside the block
            if line.hasPrefix("*CloseUI: *PageRegion") {
                if inPageRegionUI && !pageRegionInserted {
                    result.append(pageRegionLine(key: key, sizeLabel: sizeLabel, width: widthPoints, height: heightPoints))
                    pageRegionInserted = true
                }
                inPageRegionUI = false
                result.append(line)
                continue
            }

            // Fix 3: DefaultPageSize — handle at any position (inside or outside block)
            if line.hasPrefix("*DefaultPageSize:") {
                result.append("*DefaultPageSize: \(key)")
                continue
            }

            // Fix 3: DefaultPageRegion — handle at any position (inside or outside block)
            if line.hasPrefix("*DefaultPageRegion:") {
                result.append("*DefaultPageRegion: \(key)")
                continue
            }

            // Inside PageSize block — replace PageSize entries
            if inPageSizeUI {
                if line.hasPrefix("*PageSize ") {
                    if !pageSizeInserted {
                        result.append(pageSizeLine(key: key, sizeLabel: sizeLabel, width: widthPoints, height: heightPoints))
                        pageSizeInserted = true
                    }
                    // skip all original PageSize entries
                }
                continue
            }

            // Inside PageRegion block — replace PageRegion entries
            if inPageRegionUI {
                if line.hasPrefix("*PageRegion ") {
                    if !pageRegionInserted {
                        result.append(pageRegionLine(key: key, sizeLabel: sizeLabel, width: widthPoints, height: heightPoints))
                        pageRegionInserted = true
                    }
                    // skip all original PageRegion entries
                }
                continue
            }

            // DefaultImageableArea
            if line.hasPrefix("*DefaultImageableArea:") {
                result.append("*DefaultImageableArea: \(key)")
                continue
            }

            // ImageableArea entries (not Default) — insert once, skip rest
            if line.hasPrefix("*ImageableArea ") {
                if !result.contains(where: { $0.hasPrefix("*ImageableArea \(key)") }) {
                    result.append(imageableAreaLine(key: key, sizeLabel: sizeLabel, width: widthPoints, height: heightPoints))
                }
                continue
            }

            // DefaultPaperDimension
            if line.hasPrefix("*DefaultPaperDimension:") {
                result.append("*DefaultPaperDimension: \(key)")
                continue
            }

            // PaperDimension entries (not Default) — insert once, skip rest
            if line.hasPrefix("*PaperDimension ") {
                if !result.contains(where: { $0.hasPrefix("*PaperDimension \(key)") }) {
                    result.append(paperDimensionLine(key: key, sizeLabel: sizeLabel, width: widthPoints, height: heightPoints))
                }
                continue
            }

            // Fix 2: CustomPageSize True -> output exact fixed string (not a string replacement)
            if line.hasPrefix("*CustomPageSize True:") {
                result.append("*CustomPageSize False: \"pop pop pop <</PageSize[5 -2 roll]/ImagingBBox null>>setpagedevice\"")
                continue
            }

            // Remove ParamCustomPageSize lines
            if line.hasPrefix("*ParamCustomPageSize ") {
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
