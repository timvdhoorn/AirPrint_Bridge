import Foundation
import Combine

final class BridgeConfig: ObservableObject {
    private let defaults: UserDefaults

    @Published var defaultPaperWidth: Int {
        didSet { defaults.set(defaultPaperWidth, forKey: "defaultPaperWidth") }
    }
    @Published var defaultPaperHeight: Int {
        didSet { defaults.set(defaultPaperHeight, forKey: "defaultPaperHeight") }
    }
    @Published var showMenuBarIcon: Bool {
        didSet { defaults.set(showMenuBarIcon, forKey: "showMenuBarIcon") }
    }
    @Published var printers: [PrinterConfig] {
        didSet { savePrinters() }
    }

    init(suiteName: String = AirPrintBridge.suiteName) {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        self.defaults = defaults

        self.defaultPaperWidth = defaults.object(forKey: "defaultPaperWidth") as? Int ?? 100
        self.defaultPaperHeight = defaults.object(forKey: "defaultPaperHeight") as? Int ?? 40
        self.showMenuBarIcon = defaults.object(forKey: "showMenuBarIcon") as? Bool ?? true

        // Load printers directly during init to avoid @Published trigger
        if let data = defaults.data(forKey: "enabledPrinters"),
           let array = try? JSONDecoder().decode([PrinterConfig].self, from: data) {
            self.printers = array
        } else {
            self.printers = []
        }
    }

    func loadPrinters() {
        guard let data = defaults.data(forKey: "enabledPrinters"),
              let array = try? JSONDecoder().decode([PrinterConfig].self, from: data)
        else {
            printers = []
            return
        }
        printers = array
    }

    /// Sync discovered printers with saved config.
    /// New printers get default paper size. Existing printers keep their settings.
    func syncWithDiscovered(_ discovered: [DiscoveredPrinter]) {
        let existingByName = Dictionary(uniqueKeysWithValues: printers.map { ($0.name, $0) })

        printers = discovered.map { disc in
            if let existing = existingByName[disc.name] {
                return existing
            }
            return PrinterConfig(
                name: disc.name,
                widthMm: defaultPaperWidth,
                heightMm: defaultPaperHeight,
                enabled: false
            )
        }
    }

    /// Send SIGHUP to daemon to reload config.
    func notifyDaemon() {
        guard let pidString = try? String(contentsOfFile: AirPrintBridge.pidFilePath),
              let pid = Int32(pidString.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return }
        kill(pid, SIGHUP)
    }

    private func savePrinters() {
        guard let data = try? JSONEncoder().encode(printers) else { return }
        defaults.set(data, forKey: "enabledPrinters")
    }
}
