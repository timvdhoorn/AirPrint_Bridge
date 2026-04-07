import XCTest
@testable import AirPrintBridge

final class URFGeneratorTests: XCTestCase {

    // MARK: - Helpers

    private func loadFixture(_ name: String) -> String {
        let bundle = Bundle(for: type(of: self))
        let url = bundle.url(forResource: name, withExtension: "txt")!
        return try! String(contentsOf: url)
    }

    // MARK: - Zebra printer (grayscale, labels)

    func testZebraPrinter_isGrayscale() {
        let input = loadFixture("sample_lpoptions_zebra")
        let result = URFGenerator.generate(from: input)
        XCTAssertTrue(result.urf.contains("W8"), "Expected W8 (grayscale) in URF: \(result.urf)")
    }

    func testZebraPrinter_hasNoColor() {
        let input = loadFixture("sample_lpoptions_zebra")
        let result = URFGenerator.generate(from: input)
        XCTAssertFalse(result.hasColor)
    }

    func testZebraPrinter_hasNoDuplex() {
        let input = loadFixture("sample_lpoptions_zebra")
        let result = URFGenerator.generate(from: input)
        XCTAssertFalse(result.hasDuplex)
    }

    func testZebraPrinter_hasLabelMediaType() {
        let input = loadFixture("sample_lpoptions_zebra")
        let result = URFGenerator.generate(from: input)
        XCTAssertTrue(result.urf.contains("MT4"), "Expected MT4 (labels) in URF: \(result.urf)")
    }

    func testZebraPrinter_qualityCodesPresent() {
        let input = loadFixture("sample_lpoptions_zebra")
        let result = URFGenerator.generate(from: input)
        XCTAssertTrue(result.urf.contains("PQ1"), "Expected PQ1 in URF: \(result.urf)")
        XCTAssertTrue(result.urf.contains("PQ2"), "Expected PQ2 in URF: \(result.urf)")
        XCTAssertTrue(result.urf.contains("PQ3"), "Expected PQ3 in URF: \(result.urf)")
    }

    func testZebraPrinter_hasHardcodedMediaSize() {
        let input = loadFixture("sample_lpoptions_zebra")
        let result = URFGenerator.generate(from: input)
        XCTAssertTrue(result.urf.contains("MS_CUSTOM_100x150mm"), "Expected MS_CUSTOM_100x150mm in URF: \(result.urf)")
    }

    // MARK: - Color printer

    func testColorPrinter_hasSRGB24() {
        let input = loadFixture("sample_lpoptions_color")
        let result = URFGenerator.generate(from: input)
        XCTAssertTrue(result.urf.contains("SRGB24"), "Expected SRGB24 in URF: \(result.urf)")
    }

    func testColorPrinter_hasW8() {
        let input = loadFixture("sample_lpoptions_color")
        let result = URFGenerator.generate(from: input)
        XCTAssertTrue(result.urf.contains("W8"), "Expected W8 in URF: \(result.urf)")
    }

    func testColorPrinter_hasColor() {
        let input = loadFixture("sample_lpoptions_color")
        let result = URFGenerator.generate(from: input)
        XCTAssertTrue(result.hasColor)
    }

    func testColorPrinter_hasDuplex() {
        let input = loadFixture("sample_lpoptions_color")
        let result = URFGenerator.generate(from: input)
        XCTAssertTrue(result.hasDuplex)
    }

    func testColorPrinter_hasDM2andDM3() {
        let input = loadFixture("sample_lpoptions_color")
        let result = URFGenerator.generate(from: input)
        XCTAssertTrue(result.urf.contains("DM2"), "Expected DM2 in URF: \(result.urf)")
        XCTAssertTrue(result.urf.contains("DM3"), "Expected DM3 in URF: \(result.urf)")
    }

    func testColorPrinter_allQualityCodesPresent() {
        let input = loadFixture("sample_lpoptions_color")
        let result = URFGenerator.generate(from: input)
        XCTAssertTrue(result.urf.contains("PQ1"), "Expected PQ1 in URF: \(result.urf)")
        XCTAssertTrue(result.urf.contains("PQ2"), "Expected PQ2 in URF: \(result.urf)")
        XCTAssertTrue(result.urf.contains("PQ3"), "Expected PQ3 in URF: \(result.urf)")
        XCTAssertTrue(result.urf.contains("PQ4"), "Expected PQ4 in URF: \(result.urf)")
    }

    func testColorPrinter_urfHasV14Prefix() {
        let input = loadFixture("sample_lpoptions_color")
        let result = URFGenerator.generate(from: input)
        XCTAssertTrue(result.urf.hasPrefix("V1.4,"), "Expected V1.4, prefix in URF: \(result.urf)")
    }

    func testColorPrinter_hasHardcodedMediaSize() {
        let input = loadFixture("sample_lpoptions_color")
        let result = URFGenerator.generate(from: input)
        XCTAssertTrue(result.urf.contains("MS_CUSTOM_100x150mm"), "Expected MS_CUSTOM_100x150mm in URF: \(result.urf)")
    }

    // MARK: - Color matching: contains not exact

    func testColorModel_containsGray_returnsW8() {
        let result = URFGenerator.generate(from: "ColorModel/Color Mode: *DeviceGray")
        XCTAssertTrue(result.urf.contains("W8"), "Expected W8 for DeviceGray: \(result.urf)")
        XCTAssertFalse(result.hasColor)
    }

    func testColorModel_containsBlack_returnsW8() {
        let result = URFGenerator.generate(from: "ColorModel/Color Mode: *FullBlack")
        XCTAssertTrue(result.urf.contains("W8"), "Expected W8 for FullBlack: \(result.urf)")
    }

    func testColorModel_containsRGB_returnsSRGB24() {
        let result = URFGenerator.generate(from: "ColorModel/Color Mode: *sRGB")
        XCTAssertTrue(result.urf.contains("SRGB24"), "Expected SRGB24 for sRGB: \(result.urf)")
        XCTAssertTrue(result.hasColor)
    }

    func testColorModel_containsAdobeRGB_setsHasColor() {
        let result = URFGenerator.generate(from: "ColorModel/Color Mode: *AdobeRGB1998")
        XCTAssertTrue(result.urf.contains("ADOBERGB24"), "Expected ADOBERGB24: \(result.urf)")
        XCTAssertTrue(result.hasColor, "Expected hasColor=true for AdobeRGB")
    }

    func testColorModel_containsCMYK_setsHasColor() {
        let result = URFGenerator.generate(from: "ColorModel/Color Mode: *CMYK")
        XCTAssertTrue(result.urf.contains("CMYK32"), "Expected CMYK32: \(result.urf)")
        XCTAssertTrue(result.hasColor, "Expected hasColor=true for CMYK")
    }

    // MARK: - Duplex: DM3 and DM4 set hasDuplex

    func testDuplex_DM3_setsHasDuplex() {
        let result = URFGenerator.generate(from: "Duplex/Duplex: *None DuplexTumble")
        XCTAssertTrue(result.urf.contains("DM3"), "Expected DM3: \(result.urf)")
        XCTAssertTrue(result.hasDuplex, "Expected hasDuplex=true for DuplexTumble")
    }

    func testDuplex_DM4_setsHasDuplex() {
        let result = URFGenerator.generate(from: "Duplex/Duplex: *None DuplexManual")
        XCTAssertTrue(result.urf.contains("DM4"), "Expected DM4: \(result.urf)")
        XCTAssertTrue(result.hasDuplex, "Expected hasDuplex=true for DuplexManual")
    }

    // MARK: - Orientation: reverse variants before plain

    func testOrientation_reverseLandscape_isOR2() {
        let result = URFGenerator.generate(from: "Orientation/Orientation: *Portrait ReverseLandscape Landscape")
        XCTAssertTrue(result.urf.contains("OR2"), "Expected OR2 for ReverseLandscape: \(result.urf)")
        XCTAssertTrue(result.urf.contains("OR1"), "Expected OR1 for Landscape: \(result.urf)")
    }

    func testOrientation_reversePortrait_isOR3() {
        let result = URFGenerator.generate(from: "Orientation/Orientation: *Portrait ReversePortrait")
        XCTAssertTrue(result.urf.contains("OR3"), "Expected OR3 for ReversePortrait: \(result.urf)")
    }

    func testOrientation_none_isOR0() {
        let result = URFGenerator.generate(from: "Orientation/Orientation: *None")
        XCTAssertTrue(result.urf.contains("OR0"), "Expected OR0 for None: \(result.urf)")
    }

    // MARK: - InputSlot: IS5-IS10

    func testInputSlot_tray3_isIS5() {
        let result = URFGenerator.generate(from: "InputSlot/Media Source: *auto tray-3")
        XCTAssertTrue(result.urf.contains("IS5"), "Expected IS5 for tray-3: \(result.urf)")
    }

    func testInputSlot_tray4_isIS6() {
        let result = URFGenerator.generate(from: "InputSlot/Media Source: *auto tray-4")
        XCTAssertTrue(result.urf.contains("IS6"), "Expected IS6 for tray-4: \(result.urf)")
    }

    func testInputSlot_tray5_isIS7() {
        let result = URFGenerator.generate(from: "InputSlot/Media Source: *auto tray-5")
        XCTAssertTrue(result.urf.contains("IS7"), "Expected IS7 for tray-5: \(result.urf)")
    }

    func testInputSlot_envelope_isIS8() {
        let result = URFGenerator.generate(from: "InputSlot/Media Source: *auto envelope")
        XCTAssertTrue(result.urf.contains("IS8"), "Expected IS8 for envelope: \(result.urf)")
    }

    func testInputSlot_multi_isIS9() {
        let result = URFGenerator.generate(from: "InputSlot/Media Source: *auto multipurpose")
        XCTAssertTrue(result.urf.contains("IS9"), "Expected IS9 for multipurpose: \(result.urf)")
    }

    func testInputSlot_photo_isIS10() {
        let result = URFGenerator.generate(from: "InputSlot/Media Source: *auto photo")
        XCTAssertTrue(result.urf.contains("IS10"), "Expected IS10 for photo: \(result.urf)")
    }

    // MARK: - PageSize: always hardcoded MS_CUSTOM_100x150mm

    func testPageSize_alwaysHardcoded() {
        let result = URFGenerator.generate(from: "PageSize/Media Size: w595h842 *w284h114 w420h595")
        XCTAssertTrue(result.urf.contains("MS_CUSTOM_100x150mm"), "Expected hardcoded MS_CUSTOM_100x150mm: \(result.urf)")
        // Should only add the hardcoded code once, not per value
        let count = result.urf.components(separatedBy: "MS_CUSTOM_100x150mm").count - 1
        XCTAssertEqual(count, 1, "MS_CUSTOM_100x150mm should appear exactly once")
    }

    // MARK: - Empty input

    func testEmptyInput_returnsNone() {
        let result = URFGenerator.generate(from: "")
        XCTAssertEqual(result.urf, "none")
        XCTAssertFalse(result.hasColor)
        XCTAssertFalse(result.hasDuplex)
    }

    func testWhitespaceOnlyInput_returnsNone() {
        let result = URFGenerator.generate(from: "   \n  \t  ")
        XCTAssertEqual(result.urf, "none")
    }
}
