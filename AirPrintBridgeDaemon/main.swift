// AirPrintBridgeDaemon/main.swift
import Foundation

// MARK: - State

let configReader = ConfigReader()
let registrar = DNSSDRegistrar()

// MARK: - PID File

func writePIDFile() {
    let pid = ProcessInfo.processInfo.processIdentifier
    try? "\(pid)".write(toFile: AirPrintBridge.pidFilePath, atomically: true, encoding: .utf8)
    print("[Daemon] PID \(pid) written to \(AirPrintBridge.pidFilePath)")
}

func removePIDFile() {
    try? FileManager.default.removeItem(atPath: AirPrintBridge.pidFilePath)
}

// MARK: - Printer Resolution

func resolveAndRegister(printer: PrinterConfig) -> DaemonStatus.PrinterStatus {
    let name = printer.name

    // Get lpoptions for URF generation
    let lpoptionsResult = ShellCommand.run("lpoptions -l -p \(name)")
    let urf = URFGenerator.generate(from: lpoptionsResult.stdout)

    // Get printer description and location from lpstat
    let descResult = ShellCommand.run("lpstat -l -p \(name)")
    let descLines = descResult.stdout.components(separatedBy: "\n")

    let description = descLines
        .first { $0.contains("Description:") }
        .flatMap { $0.components(separatedBy: "Description:").last?.trimmingCharacters(in: .whitespaces) }
        ?? name

    let location = descLines
        .first { $0.contains("Location:") }
        .flatMap { $0.components(separatedBy: "Location:").last?.trimmingCharacters(in: .whitespaces) }
        ?? ""

    // Get make and model
    let optsResult = ShellCommand.run("lpoptions -p \(name)")
    let makeModel: String = {
        let opts = optsResult.stdout
        if let range = opts.range(of: "printer-make-and-model='") {
            let start = range.upperBound
            if let end = opts[start...].firstIndex(of: "'") {
                return String(opts[start..<end])
            }
        }
        return name
    }()

    let hostname = ProcessInfo.processInfo.hostName
        .components(separatedBy: ".").first ?? "Mac"

    // Strip PPD to configured paper size
    let ppdOk = CUPSManager.stripPPD(
        printerName: name,
        widthPoints: printer.widthPoints,
        heightPoints: printer.heightPoints,
        sizeLabel: printer.sizeLabel
    )

    if !ppdOk {
        return DaemonStatus.PrinterStatus(name: name, registered: false, error: "PPD configuratie mislukt")
    }

    // Build TXT records
    let txtRecords = TXTRecordBuilder.build(
        printerName: name,
        makeAndModel: makeModel,
        location: location,
        hostname: hostname,
        urf: urf
    )

    // Register dns-sd
    let displayName = "\(description) @ \(hostname)"
    let registered = registrar.register(
        printerName: name,
        description: displayName,
        port: 631,
        txtRecords: txtRecords
    )

    return DaemonStatus.PrinterStatus(
        name: name,
        registered: registered,
        error: registered ? nil : "dns-sd registratie mislukt"
    )
}

// MARK: - Setup

func setup() {
    print("[Daemon] Running setup...")

    registrar.unregisterAll()

    CUPSManager.ensurePermissions()
    FirewallManager.ensureCUPSAllowed()

    let printers = configReader.readPrinters()
    let enabledPrinters = printers.filter(\.enabled)

    print("[Daemon] Found \(enabledPrinters.count) enabled printer(s)")

    var printerStatuses: [DaemonStatus.PrinterStatus] = []
    for printer in enabledPrinters {
        let status = resolveAndRegister(printer: printer)
        printerStatuses.append(status)
    }

    let status = DaemonStatus(
        running: true,
        printers: printerStatuses,
        lastUpdated: Date()
    )
    StatusWriter.write(status)

    print("[Daemon] Setup complete — \(printerStatuses.filter(\.registered).count) printer(s) registered")
}

// MARK: - Cleanup

func cleanup() {
    print("[Daemon] Cleaning up...")
    registrar.unregisterAll()

    let printers = configReader.readPrinters()
    for printer in printers {
        CUPSManager.restorePPD(printerName: printer.name)
    }

    let status = DaemonStatus(running: false, printers: [], lastUpdated: Date())
    StatusWriter.write(status)

    removePIDFile()
    print("[Daemon] Cleanup complete")
}

// MARK: - Signal Handling

signal(SIGHUP) { _ in
    print("[Daemon] Received SIGHUP — reloading config...")
    setup()
}

signal(SIGTERM) { _ in
    print("[Daemon] Received SIGTERM — shutting down...")
    cleanup()
    exit(0)
}

signal(SIGINT) { _ in
    print("[Daemon] Received SIGINT — shutting down...")
    cleanup()
    exit(0)
}

// MARK: - Main

print("[Daemon] AirPrint Bridge Daemon starting...")
writePIDFile()
setup()
dispatchMain()
