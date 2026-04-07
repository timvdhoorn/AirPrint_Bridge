import SwiftUI

struct SettingsPrintersView: View {
    @EnvironmentObject private var config: BridgeConfig
    @State private var discoveredPrinters: [DiscoveredPrinter] = []

    var body: some View {
        Form {
            if config.printers.isEmpty {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "printer.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("Geen gedeelde printers")
                            .font(.headline)
                        Text("Deel printers via Systeemvoorkeuren > Printers en scanners")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            } else {
                Section {
                    ForEach(Array(config.printers.enumerated()), id: \.element.id) { index, printer in
                        printerRow(printer: printer, index: index)
                    }
                }
            }

            Section {
                Button("Vernieuw printerlijst") { refresh() }
            }
        }
        .formStyle(.grouped)
        .frame(width: 450)
        .task { await refreshAsync() }
    }

    private func printerRow(printer: PrinterConfig, index: Int) -> some View {
        let discovered = discoveredPrinters.first { $0.name == printer.name }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(printer.name).fontWeight(.medium)
                    Text(discovered?.model ?? "Onbekend model")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("AirPrint", isOn: Binding(
                    get: { printer.enabled },
                    set: { newValue in
                        var updated = printer
                        updated.enabled = newValue
                        config.printers[index] = updated
                        config.notifyDaemon()
                    }
                ))
                .toggleStyle(.switch)
            }

            HStack {
                Text("Papierformaat:").font(.caption)
                TextField("B", value: Binding(
                    get: { printer.widthMm },
                    set: { newValue in
                        var updated = printer
                        updated.widthMm = newValue
                        config.printers[index] = updated
                        config.notifyDaemon()
                    }
                ), format: .number)
                .frame(width: 60)
                Text("x").font(.caption)
                TextField("H", value: Binding(
                    get: { printer.heightMm },
                    set: { newValue in
                        var updated = printer
                        updated.heightMm = newValue
                        config.printers[index] = updated
                        config.notifyDaemon()
                    }
                ), format: .number)
                .frame(width: 60)
                Text("mm").font(.caption)
            }
        }
        .padding(.vertical, 4)
    }

    @MainActor
    private func refreshAsync() async {
        let printers = await Task.detached {
            PrinterDiscovery.discover()
        }.value
        discoveredPrinters = printers
        config.syncWithDiscovered(printers)
    }

    private func refresh() {
        Task { @MainActor in
            await refreshAsync()
        }
    }
}
