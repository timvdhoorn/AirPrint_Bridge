import XCTest
@testable import AirPrintBridge

final class ConfigReaderTests: XCTestCase {
    private let testSuiteName = "nl.labelsenmeer.airprint-bridge.test"

    override func tearDown() {
        UserDefaults(suiteName: testSuiteName)?.removePersistentDomain(forName: testSuiteName)
    }

    func testReadsEnabledPrinters() {
        let defaults = UserDefaults(suiteName: testSuiteName)!
        let printers = [
            PrinterConfig(name: "Zebra_DHL", widthMm: 100, heightMm: 40, enabled: true),
            PrinterConfig(name: "Brother", widthMm: 210, heightMm: 297, enabled: false),
        ]
        defaults.set(try! JSONEncoder().encode(printers), forKey: "enabledPrinters")

        let config = ConfigReader(suiteName: testSuiteName)
        let result = config.readPrinters()

        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].name, "Zebra_DHL")
        XCTAssertEqual(result[0].widthMm, 100)
        XCTAssertTrue(result[0].enabled)
        XCTAssertFalse(result[1].enabled)
    }

    func testReadsDefaultPaperSize() {
        let defaults = UserDefaults(suiteName: testSuiteName)!
        defaults.set(100, forKey: "defaultPaperWidth")
        defaults.set(40, forKey: "defaultPaperHeight")

        let config = ConfigReader(suiteName: testSuiteName)
        XCTAssertEqual(config.defaultPaperWidth, 100)
        XCTAssertEqual(config.defaultPaperHeight, 40)
    }

    func testEmptyDefaults_returnsEmptyPrinters() {
        let config = ConfigReader(suiteName: testSuiteName)
        XCTAssertTrue(config.readPrinters().isEmpty)
    }
}
