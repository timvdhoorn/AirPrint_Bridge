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

    /// Live discovery using `lpstat -l -p` with a 5-second timeout.
    static func discover() -> [DiscoveredPrinter] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lpstat")
        process.arguments = ["-l", "-p"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return []
        }

        // Read with timeout to prevent hanging
        let semaphore = DispatchSemaphore(value: 0)
        var outputData = Data()

        DispatchQueue.global().async {
            outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            semaphore.signal()
        }

        let timeout = semaphore.wait(timeout: .now() + 5)
        if timeout == .timedOut {
            process.terminate()
            return []
        }

        process.waitUntilExit()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        return parse(lpstatOutput: output)
    }
}
