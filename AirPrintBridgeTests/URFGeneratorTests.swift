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
