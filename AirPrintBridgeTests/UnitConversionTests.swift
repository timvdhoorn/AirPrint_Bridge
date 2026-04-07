import XCTest
@testable import AirPrintBridge

final class UnitConversionTests: XCTestCase {

    // MARK: - mmToPoints

    func testMmToPoints_100mm_returns284() {
        XCTAssertEqual(UnitConversion.mmToPoints(100), 284)
    }

    func testMmToPoints_40mm_returns114() {
        XCTAssertEqual(UnitConversion.mmToPoints(40), 114)
    }

    func testMmToPoints_210mm_returnsA4Width596() {
        XCTAssertEqual(UnitConversion.mmToPoints(210), 596)
    }

    func testMmToPoints_297mm_returnsA4Height842() {
        XCTAssertEqual(UnitConversion.mmToPoints(297), 842)
    }

    // MARK: - pointsToMm

    func testPointsToMm_284points_returns100mm_roundTrip() {
        XCTAssertEqual(UnitConversion.pointsToMm(284), 100)
    }
}
