import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var config: BridgeConfig
    @State private var daemonStatus: DaemonStatus?
    @State private var discoveredPrinters: [DiscoveredPrinter] = []
    @State private var hasLoaded = false

    private var isRunning: Bool { daemonStatus?.running ?? false }
    private var enabledCount: Int { config.printers.filter(\.enabled).count }
    private var totalCount: Int { config.printers.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AirPrint Bridge")
                        .font(.headline)
                    Text("\(enabledCount) van \(totalCount) printers gedeeld")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(isRunning ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    Text(isRunning ? "Actief" : "Gestopt")
                        .font(.caption)
                        .foregroundColor(isRunning ? .green : .red)
                }
            }

            Divider()

            // Printer list
            if config.printers.isEmpty {
                Text("Geen gedeelde printers gevonden")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(config.printers.enumerated()), id: \.element.id) { index, printer in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(printer.name)
                                    .fontWeight(.bold)
                                Text("\(printer.sizeLabel) mm")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { printer.enabled },
                                set: { newValue in
                                    var updated = printer
                                    updated.enabled = newValue
                                    config.printers[index] = updated
                                    config.notifyDaemon()
                                }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                        .opacity(printer.enabled ? 1.0 : 0.6)
                    }
                }
            }

            Divider()

            // Footer
            HStack {
                if #available(macOS 14, *) {
                    SettingsLink {
                        Text("Instellingen")
                    }
                } else {
                    Button("Instellingen") {
                        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                    }
                }
                Button("Vernieuw") { refresh() }
                Spacer()
                Button("Stop") {
                    NSApplication.shared.terminate(nil)
                }
                .foregroundColor(.red)
            }
        }
        .padding()
        .frame(width: 320)
        .onAppear {
            if !hasLoaded {
                hasLoaded = true
                refresh()
            }
        }
    }

    private func refresh() {
        daemonStatus = StatusReader.read()
        Task.detached {
            let printers = PrinterDiscovery.discover()
            await MainActor.run {
                discoveredPrinters = printers
                config.syncWithDiscovered(printers)
            }
        }
    }
}
