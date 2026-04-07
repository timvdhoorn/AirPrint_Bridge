import XCTest
@testable import AirPrintBridge

final class UnitConversionTests: XCTestCase {

    // MARK: - mmToPoints

    func testMmToPoints_100mm_returns283() {
        XCTAssertEqual(UnitConversion.mmToPoints(100), 283)
    }

    func testMmToPoints_40mm_returns113() {
        XCTAssertEqual(UnitConversion.mmToPoints(40), 113)
    }

    func testMmToPoints_210mm_returnsA4Width595() {
        XCTAssertEqual(UnitConversion.mmToPoints(210), 595)
    }

    func testMmToPoints_297mm_returnsA4Height842() {
        XCTAssertEqual(UnitConversion.mmToPoints(297), 842)
    }

    // MARK: - pointsToMm

    func testPointsToMm_283points_returns100mm_roundTrip() {
        XCTAssertEqual(UnitConversion.pointsToMm(283), 100)
    }
}
