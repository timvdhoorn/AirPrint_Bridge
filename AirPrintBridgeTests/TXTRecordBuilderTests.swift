import XCTest
@testable import AirPrintBridge

final class TXTRecordBuilderTests: XCTestCase {

    // MARK: - Zebra printer (grayscale, no duplex)

    private var zebraURF: URFResult {
        URFResult(urf: "V1.4,W8", hasColor: false, hasDuplex: false)
    }

    func testZebra_containsTxtvers() {
        let result = TXTRecordBuilder.build(
            printerName: "Zebra_DHL",
            makeAndModel: "Zebra ZPL Label Printer",
            location: "Magazijn",
            hostname: "MacMini",
            urf: zebraURF
        )
        XCTAssertTrue(result.contains("txtvers=1"))
    }

    func testZebra_containsResourcePath() {
        let result = TXTRecordBuilder.build(
            printerName: "Zebra_DHL",
            makeAndModel: "Zebra ZPL Label Printer",
            location: "Magazijn",
            hostname: "MacMini",
            urf: zebraURF
        )
        XCTAssertTrue(result.contains("rp=printers/Zebra_DHL"))
    }

    func testZebra_containsTy() {
        let result = TXTRecordBuilder.build(
            printerName: "Zebra_DHL",
            makeAndModel: "Zebra ZPL Label Printer",
            location: "Magazijn",
            hostname: "MacMini",
            urf: zebraURF
        )
        XCTAssertTrue(result.contains("ty=Zebra ZPL Label Printer"))
    }

    func testZebra_containsProduct() {
        let result = TXTRecordBuilder.build(
            printerName: "Zebra_DHL",
            makeAndModel: "Zebra ZPL Label Printer",
            location: "Magazijn",
            hostname: "MacMini",
            urf: zebraURF
        )
        XCTAssertTrue(result.contains("product=(Zebra ZPL Label Printer)"))
    }

    func testZebra_containsNote() {
        let result = TXTRecordBuilder.build(
            printerName: "Zebra_DHL",
            makeAndModel: "Zebra ZPL Label Printer",
            location: "Magazijn",
            hostname: "MacMini",
            urf: zebraURF
        )
        XCTAssertTrue(result.contains("note=Magazijn via MacMini"))
    }

    func testZebra_containsPdl() {
        let result = TXTRecordBuilder.build(
            printerName: "Zebra_DHL",
            makeAndModel: "Zebra ZPL Label Printer",
            location: "Magazijn",
            hostname: "MacMini",
            urf: zebraURF
        )
        XCTAssertTrue(result.contains("pdl=application/pdf,image/jpeg,image/urf"))
    }

    func testZebra_containsURF() {
        let result = TXTRecordBuilder.build(
            printerName: "Zebra_DHL",
            makeAndModel: "Zebra ZPL Label Printer",
            location: "Magazijn",
            hostname: "MacMini",
            urf: zebraURF
        )
        XCTAssertTrue(result.contains("URF=V1.4,W8"))
    }

    func testZebra_colorIsFalse() {
        let result = TXTRecordBuilder.build(
            printerName: "Zebra_DHL",
            makeAndModel: "Zebra ZPL Label Printer",
            location: "Magazijn",
            hostname: "MacMini",
            urf: zebraURF
        )
        XCTAssertTrue(result.contains("Color=F"))
    }

    func testZebra_duplexIsFalse() {
        let result = TXTRecordBuilder.build(
            printerName: "Zebra_DHL",
            makeAndModel: "Zebra ZPL Label Printer",
            location: "Magazijn",
            hostname: "MacMini",
            urf: zebraURF
        )
        XCTAssertTrue(result.contains("Duplex=F"))
    }

    func testZebra_recordCount() {
        let result = TXTRecordBuilder.build(
            printerName: "Zebra_DHL",
            makeAndModel: "Zebra ZPL Label Printer",
            location: "Magazijn",
            hostname: "MacMini",
            urf: zebraURF
        )
        XCTAssertEqual(result.count, 10)
    }

    // MARK: - Color printer with duplex

    func testColorDuplex_colorIsTrue() {
        let urf = URFResult(urf: "V1.4,SRGB24,DM2", hasColor: true, hasDuplex: true)
        let result = TXTRecordBuilder.build(
            printerName: "ColorPrinter",
            makeAndModel: "HP Color LaserJet",
            location: "Office",
            hostname: "MacPro",
            urf: urf
        )
        XCTAssertTrue(result.contains("Color=T"))
    }

    func testColorDuplex_duplexIsTrue() {
        let urf = URFResult(urf: "V1.4,SRGB24,DM2", hasColor: true, hasDuplex: true)
        let result = TXTRecordBuilder.build(
            printerName: "ColorPrinter",
            makeAndModel: "HP Color LaserJet",
            location: "Office",
            hostname: "MacPro",
            urf: urf
        )
        XCTAssertTrue(result.contains("Duplex=T"))
    }

    // MARK: - Empty location

    func testEmptyLocation_noteFormatsCorrectly() {
        let urf = URFResult(urf: "V1.4,W8", hasColor: false, hasDuplex: false)
        let result = TXTRecordBuilder.build(
            printerName: "Printer1",
            makeAndModel: "Generic Printer",
            location: "",
            hostname: "Mac",
            urf: urf
        )
        XCTAssertTrue(result.contains("note= via Mac"))
    }

    // MARK: - Record order

    func testRecordOrder() {
        let urf = URFResult(urf: "V1.4,W8", hasColor: false, hasDuplex: false)
        let result = TXTRecordBuilder.build(
            printerName: "TestPrinter",
            makeAndModel: "Test Model",
            location: "Room",
            hostname: "Host",
            urf: urf
        )
        XCTAssertEqual(result[0], "txtvers=1")
        XCTAssertEqual(result[1], "qtotal=1")
        XCTAssertTrue(result[2].hasPrefix("rp=printers/"))
        XCTAssertTrue(result[3].hasPrefix("ty="))
        XCTAssertTrue(result[4].hasPrefix("product=("))
        XCTAssertTrue(result[5].hasPrefix("note="))
        XCTAssertTrue(result[6].hasPrefix("pdl="))
        XCTAssertTrue(result[7].hasPrefix("URF="))
        XCTAssertTrue(result[8].hasPrefix("Color="))
        XCTAssertTrue(result[9].hasPrefix("Duplex="))
    }
}
