import Foundation

struct DiscoveredPrinter: Identifiable {
    let name: String
    let model: String
    let location: String
    var id: String { name }
}

enum PrinterDiscovery {

    /// Parse `lpstat -l -p` output to find shared printers.
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

    /// Live discovery using `lpstat -l -p`.
    static func discover() -> [DiscoveredPrinter] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lpstat")
        process.arguments = ["-l", "-p"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.launch()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        return parse(lpstatOutput: output)
    }
}
