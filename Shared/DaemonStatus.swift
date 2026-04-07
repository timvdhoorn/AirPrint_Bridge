import Foundation

struct DaemonStatus: Codable {
    let running: Bool
    let printers: [PrinterStatus]
    let lastUpdated: Date

    struct PrinterStatus: Codable {
        let name: String
        let registered: Bool
        let error: String?
    }
}
