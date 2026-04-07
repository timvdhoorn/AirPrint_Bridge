import SwiftUI

struct PopoverView: View {
    @EnvironmentObject private var config: BridgeConfig
    @State private var daemonStatus: DaemonStatus?
    @State private var discoveredPrinters: [DiscoveredPrinter] = []

    private var isRunning: Bool { daemonStatus?.running ?? false }
    private var enabledCount: Int { config.printers.filter(\.enabled).count }
    private var totalCount: Int { config.printers.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            Divider()
            printerList
            Divider()
            footer
        }
        .padding()
        .frame(width: 320)
        .task { await refreshAsync() }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("AirPrint Bridge")
                    .font(.headline)
                Spacer()
                statusBadge
            }
            Text("\(enabledCount) van \(totalCount) printers gedeeld")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isRunning ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(isRunning ? "Actief" : "Gestopt")
                .font(.caption)
                .foregroundColor(isRunning ? .green : .red)
        }
    }

    // MARK: - Printer List

    private var printerList: some View {
        Group {
            if config.printers.isEmpty {
                Text("Geen gedeelde printers gevonden")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(config.printers.enumerated()), id: \.element.id) { index, printer in
                        printerRow(printer: printer, index: index)
                    }
                }
            }
        }
    }

    private func printerRow(printer: PrinterConfig, index: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(printer.name)
                    .font(.body)
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

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button("Instellingen") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            Button("Vernieuw") {
                refresh()
            }
            Spacer()
            Button(isRunning ? "Stop" : "Start") {
                // TODO: start/stop daemon
            }
        }
    }

    // MARK: - Actions

    private func refreshAsync() async {
        let printers = await Task.detached {
            PrinterDiscovery.discover()
        }.value
        discoveredPrinters = printers
        config.syncWithDiscovered(printers)
        daemonStatus = StatusReader.read()
    }

    private func refresh() {
        Task { await refreshAsync() }
    }
}
