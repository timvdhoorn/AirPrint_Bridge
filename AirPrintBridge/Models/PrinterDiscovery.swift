import Foundation

struct DiscoveredPrinter: Identifiable {
    let name: String
    let model: String
    let location: String
    var id: String { name }
}

enum PrinterDiscovery {

    /// Parse `lpstat -l -p` output to extract printer names and metadata.
    static func parse(lpstatOutput: String) -> [DiscoveredPrinter] {
        let lines = lpstatOutput.components(separatedBy: "\n")
        var results: [DiscoveredPrinter] = []

        var currentName: String?
        var currentModel = ""
        var currentLocation = ""
        var currentShared = false

        func flush() {
            guard let name = currentName, currentShared else { return }
            results.append(DiscoveredPrinter(name: name, model: currentModel, location: currentLocation))
        }

        for line in lines {
            if line.hasPrefix("printer ") {
                flush()
                let parts = line.dropFirst("printer ".count).components(separatedBy: " ")
                currentName = parts.first ?? ""
                currentModel = ""
                currentLocation = ""
                currentShared = false
            } else if line.hasPrefix("\t") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("Make and Model: ") {
                    currentModel = String(trimmed.dropFirst("Make and Model: ".count))
                } else if trimmed.hasPrefix("Location: ") {
                    currentLocation = String(trimmed.dropFirst("Location: ".count))
                } else if trimmed.hasPrefix("Shared: ") {
                    currentShared = trimmed.dropFirst("Shared: ".count) == "yes"
                }
            }
        }

        flush()
        return results
    }

    /// Check if a printer is shared using lpoptions and printers.conf
    /// (matches the original bash script logic).
    private static func isShared(printerName: String) -> Bool {
        // Check 1: lpoptions -p <name> for printer-is-shared=true
        let opts = shellOutput("/usr/bin/lpoptions", args: ["-p", printerName])
        if opts.contains("printer-is-shared=true") {
            return true
        }

        // Check 2: /etc/cups/printers.conf for Shared Yes
        if let conf = try? String(contentsOfFile: "/etc/cups/printers.conf", encoding: .utf8) {
            let lines = conf.components(separatedBy: "\n")
            var inPrinterBlock = false
            for line in lines {
                if line.contains("<Printer \(printerName)>") || line.contains("<DefaultPrinter \(printerName)>") {
                    inPrinterBlock = true
                } else if line.contains("</Printer>") || line.contains("</DefaultPrinter>") {
                    inPrinterBlock = false
                } else if inPrinterBlock && line.trimmingCharacters(in: .whitespaces) == "Shared Yes" {
                    return true
                }
            }
        }

        return false
    }

    /// Get printer model from lpoptions.
    private static func getModel(printerName: String) -> String {
        let opts = shellOutput("/usr/bin/lpoptions", args: ["-p", printerName])
        // Parse printer-make-and-model='...' or printer-make-and-model=...
        if let range = opts.range(of: "printer-make-and-model='") {
            let start = range.upperBound
            if let end = opts[start...].firstIndex(of: "'") {
                return String(opts[start..<end])
            }
        }
        if let range = opts.range(of: "printer-make-and-model=") {
            let start = range.upperBound
            let rest = opts[start...]
            if let end = rest.firstIndex(of: " ") {
                return String(rest[..<end])
            }
            return String(rest)
        }
        return printerName
    }

    /// Get printer location from lpstat -l -p.
    private static func getLocation(printerName: String) -> String {
        let output = shellOutput("/usr/bin/lpstat", args: ["-l", "-p", printerName])
        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Location: ") {
                return String(trimmed.dropFirst("Location: ".count))
            }
        }
        return ""
    }

    /// Live discovery: list all printers, filter shared ones.
    static func discover() -> [DiscoveredPrinter] {
        // Get all printer names from lpstat -p
        let output = shellOutput("/usr/bin/lpstat", args: ["-p"])
        if output.isEmpty || output.contains("No destinations") {
            return []
        }

        var results: [DiscoveredPrinter] = []

        for line in output.components(separatedBy: "\n") {
            guard line.hasPrefix("printer ") else { continue }
            let parts = line.dropFirst("printer ".count).components(separatedBy: " ")
            guard let name = parts.first, !name.isEmpty else { continue }

            if isShared(printerName: name) {
                let model = getModel(printerName: name)
                let location = getLocation(printerName: name)
                results.append(DiscoveredPrinter(name: name, model: model, location: location))
            }
        }

        return results
    }

    /// Run a command and return stdout.
    private static func shellOutput(_ path: String, args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return ""
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return String(data: data, encoding: .utf8) ?? ""
    }
}
