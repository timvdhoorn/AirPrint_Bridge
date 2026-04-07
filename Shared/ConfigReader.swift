import Foundation

final class ConfigReader {
    private let defaults: UserDefaults

    var defaultPaperWidth: Int { defaults.integer(forKey: "defaultPaperWidth") }
    var defaultPaperHeight: Int { defaults.integer(forKey: "defaultPaperHeight") }

    init(suiteName: String = AirPrintBridge.suiteName) {
        self.defaults = UserDefaults(suiteName: suiteName) ?? .standard
    }

    func readPrinters() -> [PrinterConfig] {
        guard let data = defaults.data(forKey: "enabledPrinters") else { return [] }
        return (try? JSONDecoder().decode([PrinterConfig].self, from: data)) ?? []
    }
}
