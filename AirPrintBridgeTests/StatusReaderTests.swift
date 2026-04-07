import XCTest
@testable import AirPrintBridge

final class StatusReaderTests: XCTestCase {
    private let testPath = NSTemporaryDirectory() + "airprint-bridge-test-status.json"

    override func tearDown() {
        try? FileManager.default.removeItem(atPath: testPath)
    }

    func testReadsValidStatus() {
        let json = """
        {
          "running": true,
          "printers": [
            {"name": "Zebra_DHL", "registered": true, "error": null}
          ],
          "lastUpdated": "2026-04-07T10:00:00Z"
        }
        """
        FileManager.default.createFile(atPath: testPath, contents: json.data(using: .utf8))

        let status = StatusReader.read(from: testPath)
        XCTAssertNotNil(status)
        XCTAssertTrue(status!.running)
        XCTAssertEqual(status!.printers.count, 1)
        XCTAssertEqual(status!.printers[0].name, "Zebra_DHL")
    }

    func testMissingFile_returnsNil() {
        let status = StatusReader.read(from: "/tmp/nonexistent-airprint-status.json")
        XCTAssertNil(status)
    }
}
