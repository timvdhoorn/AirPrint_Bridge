import XCTest
@testable import AirPrintBridge

final class PPDStripperTests: XCTestCase {

    // MARK: - Helpers

    private var samplePPD: String {
        guard let url = Bundle(for: type(of: self)).url(forResource: "sample_ppd_zebra", withExtension: "ppd"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("sample_ppd_zebra.ppd fixture not found in test bundle")
            return ""
        }
        return content
    }

    private func stripped() -> String {
        PPDStripper.strip(
            ppd: samplePPD,
            widthPoints: 283,
            heightPoints: 113,
            sizeLabel: "100x40"
        )
    }

    // MARK: - Test 1: Strips to single PageSize

    func testStripsToSinglePageSize() {
        let output = stripped()
        XCTAssertTrue(output.contains("*PageSize w283h113/100x40:"), "Should contain new PageSize entry")
        XCTAssertFalse(output.contains("w288h432"), "Should not contain original size w288h432")
        XCTAssertFalse(output.contains("w162h288"), "Should not contain original size w162h288")
        XCTAssertFalse(output.contains("w288h576"), "Should not contain original size w288h576")
    }

    // MARK: - Test 2: Updates all defaults

    func testUpdatesAllDefaults() {
        let output = stripped()
        XCTAssertTrue(output.contains("*DefaultPageSize: w283h113"), "DefaultPageSize should be updated")
        XCTAssertTrue(output.contains("*DefaultPageRegion: w283h113"), "DefaultPageRegion should be updated")
        XCTAssertTrue(output.contains("*DefaultImageableArea: w283h113"), "DefaultImageableArea should be updated")
        XCTAssertTrue(output.contains("*DefaultPaperDimension: w283h113"), "DefaultPaperDimension should be updated")
    }

    // MARK: - Test 3: Disables CustomPageSize and removes params

    func testDisablesCustomPageSize() {
        let output = stripped()
        // Fix 2: exact replacement string from bash awk must be used (not just True→False substitution)
        XCTAssertTrue(
            output.contains("*CustomPageSize False: \"pop pop pop <</PageSize[5 -2 roll]/ImagingBBox null>>setpagedevice\""),
            "CustomPageSize should be replaced with exact bash awk output string"
        )
        XCTAssertFalse(output.contains("*CustomPageSize True:"), "CustomPageSize True should be removed")
        XCTAssertFalse(output.contains("*ParamCustomPageSize"), "ParamCustomPageSize lines should be removed")
    }

    // MARK: - Test 4: Preserves non-page content

    func testPreservesNonPageContent() {
        let output = stripped()
        XCTAssertTrue(output.contains("*Manufacturer: \"Zebra\""), "Manufacturer should be preserved")
        XCTAssertTrue(output.contains("*OpenUI *ColorModel"), "ColorModel UI block should be preserved")
        XCTAssertTrue(output.contains("*ColorModel Gray/Grayscale:"), "ColorModel Gray entry should be preserved")
    }

    // MARK: - Test 5: Correct ImageableArea and PaperDimension formats

    func testCorrectImageableAreaAndPaperDimension() {
        let output = stripped()
        XCTAssertTrue(
            output.contains("*ImageableArea w283h113/100x40: \"0 0 283 113\""),
            "ImageableArea should have correct format"
        )
        XCTAssertTrue(
            output.contains("*PaperDimension w283h113/100x40: \"283 113\""),
            "PaperDimension should have correct format"
        )
    }
}
