import Foundation

final class DNSSDRegistrar {
    private var processes: [String: Process] = [:]

    /// Register a printer for AirPrint via dns-sd.
    func register(printerName: String, description: String, port: Int, txtRecords: [String]) -> Bool {
        unregister(printerName: printerName)

        var args = [
            "dns-sd", "-R", description,
            AirPrintBridge.service, AirPrintBridge.domain,
            "\(port)"
        ]
        args.append(contentsOf: txtRecords)

        guard let process = ShellCommand.runBackgroundDirect(args) else {
            print("[DNSSDRegistrar] Failed to start dns-sd for \(printerName)")
            return false
        }

        processes[printerName] = process
        print("[DNSSDRegistrar] Registered \(printerName) (PID: \(process.processIdentifier))")
        return true
    }

    /// Unregister a single printer.
    func unregister(printerName: String) {
        guard let process = processes.removeValue(forKey: printerName) else { return }
        if process.isRunning { process.terminate() }
        print("[DNSSDRegistrar] Unregistered \(printerName)")
    }

    /// Unregister all printers.
    func unregisterAll() {
        for (name, process) in processes {
            if process.isRunning { process.terminate() }
            print("[DNSSDRegistrar] Unregistered \(name)")
        }
        processes.removeAll()
    }

    var registeredPrinters: [String] { Array(processes.keys) }

    deinit { unregisterAll() }
}
