import XCTest
@testable import AirPrintBridge

final class PrinterDiscoveryTests: XCTestCase {

    // MARK: - Helpers

    private var sampleLpstatOutput: String {
        guard let url = Bundle(for: type(of: self)).url(forResource: "sample_lpstat_output", withExtension: "txt"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            XCTFail("sample_lpstat_output.txt fixture not found in test bundle")
            return ""
        }
        return content
    }

    // MARK: - Test 1: Parses shared printers (excludes Shared: no)

    func testParsesSharedPrinters() {
        let printers = PrinterDiscovery.parse(lpstatOutput: sampleLpstatOutput)

        XCTAssertEqual(printers.count, 2, "Should return exactly 2 shared printers (HP_Private excluded)")

        let zebra = printers[0]
        XCTAssertEqual(zebra.name, "Zebra_DHL")
        XCTAssertEqual(zebra.model, "Zebra ZPL Label Printer")
        XCTAssertEqual(zebra.location, "Magazijn")
        XCTAssertEqual(zebra.id, "Zebra_DHL")

        let brother = printers[1]
        XCTAssertEqual(brother.name, "Brother_Kantoor")
        XCTAssertEqual(brother.model, "Brother HL-L2350DW")
        XCTAssertEqual(brother.location, "Kantoor")
    }

    // MARK: - Test 2: Empty input returns empty array

    func testEmptyInputReturnsEmptyArray() {
        let printers = PrinterDiscovery.parse(lpstatOutput: "")
        XCTAssertTrue(printers.isEmpty, "Empty input should return empty array")
    }
}
