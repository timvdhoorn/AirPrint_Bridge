import SwiftUI

struct SettingsGeneralView: View {
    @EnvironmentObject private var config: BridgeConfig
    @StateObject private var daemonManager = DaemonManager()
    @State private var errorMessage: String?
    @State private var showUninstallConfirm = false

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

            Section("Daemon beheer") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Status")
                        Text(daemonManager.statusDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Herlaad") {
                        config.notifyDaemon()
                    }
                }

                Button("Daemon stoppen") {
                    stopDaemon()
                }

                Button("Daemon verwijderen") {
                    showUninstallConfirm = true
                }
                .foregroundColor(.red)
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
        .alert("Daemon verwijderen?", isPresented: $showUninstallConfirm) {
            Button("Annuleer", role: .cancel) { }
            Button("Verwijderen", role: .destructive) {
                uninstallDaemon()
            }
        } message: {
            Text("Dit stopt de achtergrondservice en herstelt alle printerinstellingen naar origineel. AirPrint wordt uitgeschakeld.")
        }
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
            errorMessage = "Kon de achtergrondservice niet \(enable ? "starten" : "stoppen"): \(error.localizedDescription)"
        }
    }

    private func stopDaemon() {
        // Send stop notification to daemon
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name(AirPrintBridge.reloadNotification + ".stop"),
            object: nil
        )
        errorMessage = nil
    }

    private func uninstallDaemon() {
        // Send cleanup notification
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name(AirPrintBridge.reloadNotification + ".stop"),
            object: nil
        )

        // Unregister from SMAppService
        do {
            try daemonManager.unregister()
        } catch {
            // Ignore — daemon may already be unregistered
        }

        // Clear all config
        config.printers = []
        config.savePrinters()

        errorMessage = nil
    }
}
