import Foundation

enum StatusWriter {
    static func write(_ status: DaemonStatus, to path: String = AirPrintBridge.statusFilePath) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(status) else { return }
        FileManager.default.createFile(atPath: path, contents: data)
    }
}
