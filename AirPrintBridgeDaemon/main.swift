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

    let rawDescription = descLines
        .first { $0.contains("Description:") }
        .flatMap { $0.components(separatedBy: "Description:").last?.trimmingCharacters(in: .whitespaces) }

    let hostname = ProcessInfo.processInfo.hostName
        .components(separatedBy: ".").first ?? "Mac"

    let description = (rawDescription?.isEmpty == false) ? rawDescription! : "\(name) @ \(hostname)"

    let location = descLines
        .first { $0.contains("Location:") }
        .flatMap { $0.components(separatedBy: "Location:").last?.trimmingCharacters(in: .whitespaces) }
        ?? ""

    // Get make and model
    let optsResult = ShellCommand.run("lpoptions -p \(name)")
    let makeModel: String = {
        let opts = optsResult.stdout
        // Try quoted format first: printer-make-and-model='...'
        if let range = opts.range(of: "printer-make-and-model='") {
            let start = range.upperBound
            if let end = opts[start...].firstIndex(of: "'") {
                return String(opts[start..<end])
            }
        }
        // Try unquoted format: printer-make-and-model=VALUE SPACE
        if let range = opts.range(of: "printer-make-and-model=") {
            let start = range.upperBound
            let rest = opts[start...]
            if let end = rest.firstIndex(of: " ") {
                return String(rest[..<end])
            }
            return String(rest)
        }
        return name
    }()

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

    // Get device URI and extract port
    let uriResult = ShellCommand.run("lpstat -v \(name)")
    let deviceUri = uriResult.stdout.components(separatedBy: " ")
        .dropFirst(2).first?
        .trimmingCharacters(in: CharacterSet(charactersIn: ":")) ?? ""

    let port: Int
    if deviceUri.hasPrefix("ipp://") || deviceUri.hasPrefix("ipps://") {
        // Extract port from URI: ipp://host:port/path
        let urlParts = deviceUri.components(separatedBy: "/")
        if urlParts.count >= 3 {
            let hostPort = urlParts[2]
            if let colonRange = hostPort.range(of: ":", options: .backwards) {
                port = Int(hostPort[colonRange.upperBound...]) ?? 631
            } else {
                port = 631
            }
        } else {
            port = 631
        }
    } else {
        port = 631
    }

    // Register dns-sd
    let displayName = description
    let registered = registrar.register(
        printerName: name,
        description: displayName,
        port: port,
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

    // Restore ALL printer PPDs, not just configured ones
    let allPrinters = ShellCommand.run("lpstat -p 2>/dev/null | awk '{print $2}'")
    for name in allPrinters.stdout.components(separatedBy: "\n").filter({ !$0.isEmpty }) {
        CUPSManager.restorePPD(printerName: name)
    }

    // Revert CUPS config
    CUPSManager.revertConfig()

    // Kill orphaned dns-sd processes
    let pids = ShellCommand.run("pgrep -f 'dns-sd -R'")
    for pidStr in pids.stdout.components(separatedBy: "\n").filter({ !$0.isEmpty }) {
        if let pid = Int32(pidStr) {
            let args = ShellCommand.run("ps -p \(pid) -o args=")
            if args.stdout.contains(AirPrintBridge.service) {
                kill(pid, SIGTERM)
            }
        }
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
