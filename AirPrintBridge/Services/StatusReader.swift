import Foundation

enum StatusReader {
    static func read(from path: String = AirPrintBridge.statusFilePath) -> DaemonStatus? {
        guard let data = FileManager.default.contents(atPath: path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(DaemonStatus.self, from: data)
    }
}
