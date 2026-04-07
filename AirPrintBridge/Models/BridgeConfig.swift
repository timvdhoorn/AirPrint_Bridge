import Foundation
import Combine

final class BridgeConfig: ObservableObject {
    private let defaults: UserDefaults

    @Published var defaultPaperWidth: Int
    @Published var defaultPaperHeight: Int
    @Published var showMenuBarIcon: Bool
    @Published var printers: [PrinterConfig]

    init(suiteName: String = AirPrintBridge.suiteName) {
        let defaults = UserDefaults(suiteName: suiteName) ?? .standard
        self.defaults = defaults

        // Set all properties before super.init — no didSet, no publish
        self.defaultPaperWidth = defaults.object(forKey: "defaultPaperWidth") as? Int ?? 100
        self.defaultPaperHeight = defaults.object(forKey: "defaultPaperHeight") as? Int ?? 40
        self.showMenuBarIcon = defaults.object(forKey: "showMenuBarIcon") as? Bool ?? true

        if let data = defaults.data(forKey: "enabledPrinters"),
           let array = try? JSONDecoder().decode([PrinterConfig].self, from: data) {
            self.printers = array
        } else {
            self.printers = []
        }
    }

    func savePaperWidth() {
        defaults.set(defaultPaperWidth, forKey: "defaultPaperWidth")
    }

    func savePaperHeight() {
        defaults.set(defaultPaperHeight, forKey: "defaultPaperHeight")
    }

    func saveShowMenuBarIcon() {
        defaults.set(showMenuBarIcon, forKey: "showMenuBarIcon")
    }

    func savePrinters() {
        guard let data = try? JSONEncoder().encode(printers) else { return }
        defaults.set(data, forKey: "enabledPrinters")
    }

    func loadPrinters() {
        guard let data = defaults.data(forKey: "enabledPrinters"),
              let array = try? JSONDecoder().decode([PrinterConfig].self, from: data)
        else { return }
        printers = array
    }

    func syncWithDiscovered(_ discovered: [DiscoveredPrinter]) {
        let existingByName = Dictionary(uniqueKeysWithValues: printers.map { ($0.name, $0) })

        let synced = discovered.map { disc in
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
        printers = synced
        savePrinters()
    }

    func notifyDaemon() {
        savePrinters()
        guard let pidString = try? String(contentsOfFile: AirPrintBridge.pidFilePath),
              let pid = Int32(pidString.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return }
        kill(pid, SIGHUP)
    }
}
