import Foundation

enum TXTRecordBuilder {

    static func build(
        printerName: String,
        makeAndModel: String,
        location: String,
        hostname: String,
        urf: URFResult
    ) -> [String] {
        [
            "txtvers=1",
            "qtotal=1",
            "rp=printers/\(printerName)",
            "ty=\(makeAndModel)",
            "product=(\(makeAndModel))",
            "note=\(location) via \(hostname)",
            "pdl=application/pdf,image/jpeg,image/urf",
            "URF=\(urf.urf)",
            "Color=\(urf.hasColor ? "T" : "F")",
            "Duplex=\(urf.hasDuplex ? "T" : "F")"
        ]
    }
}
