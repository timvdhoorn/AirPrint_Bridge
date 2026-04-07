import SwiftUI

struct SettingsGeneralView: View {
    @EnvironmentObject private var config: BridgeConfig
    @StateObject private var daemonManager = DaemonManager()
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(
                    get: { daemonManager.isRegistered },
                    set: { toggleDaemon(enable: $0) }
                )) {
                    VStack(alignment: .leading) {
                        Text("Start bij opstarten")
                        Text("Draait als achtergrondservice, ook zonder dat iemand is ingelogd")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $config.showMenuBarIcon) {
                    VStack(alignment: .leading) {
                        Text("Toon icoontje in menubalk")
                        Text("Als uitgeschakeld, open Instellingen via Spotlight of de app opnieuw")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Standaard papierformaat") {
                HStack {
                    TextField("Breedte", value: $config.defaultPaperWidth, format: .number)
                        .frame(width: 80)
                    Text("x")
                    TextField("Hoogte", value: $config.defaultPaperHeight, format: .number)
                        .frame(width: 80)
                    Text("mm")
                }
            }

            if let errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450)
    }

    private func toggleDaemon(enable: Bool) {
        do {
            if enable {
                try daemonManager.register()
            } else {
                try daemonManager.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = "Kon de achtergrondservice niet \(enable ? "starten" : "stoppen"): \(error.localizedDescription). Voor deze functie is een Developer ID-signed build nodig."
        }
    }
}
