import Foundation

enum CUPSManager {
    private static let configPath = AirPrintBridge.cupsConfigPath
    private static let ppdBasePath = AirPrintBridge.ppdBasePath

    private static func log(_ message: String) {
        print("[CUPSManager] \(message)")
    }

    // MARK: - Public API

    @discardableResult
    static func ensurePermissions() -> Bool {
        var changed = false

        // Step 1: Ensure Allow @LOCAL in cupsd.conf
        let configContent = (try? String(contentsOfFile: configPath, encoding: .utf8)) ?? ""

        if !configContent.contains("Allow @LOCAL") {
            log("Allow @LOCAL not found in cupsd.conf — patching")

            let backupPath = configPath + ".bak"
            if !FileManager.default.fileExists(atPath: backupPath) {
                ShellCommand.run("cp \(configPath) \(backupPath)")
                log("Backed up cupsd.conf to \(backupPath)")
            }

            // Insert `Allow @LOCAL` after `Order allow,deny` inside <Location />
            let sedCmd = """
            sed -i '' '/^<Location \\/>/{:a;n;/Order allow,deny/a\\    Allow @LOCAL
            ;ba}' \(configPath)
            """
            ShellCommand.run(sedCmd)

            let validation = ShellCommand.run("cupsd -t")
            if validation.success {
                log("cupsd.conf valid — restarting CUPS")
                restartCUPS()
                changed = true
            } else {
                log("cupsd.conf invalid after patch — reverting. stderr: \(validation.stderr)")
                revertConfig()
            }
        } else {
            log("Allow @LOCAL already present in cupsd.conf")
        }

        // Step 2: Ensure all shared printers allow all users
        let lpstatResult = ShellCommand.run("lpstat -p | awk '{print $2}'")
        let printerNames = lpstatResult.stdout
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        for name in printerNames {
            let optionsResult = ShellCommand.run("lpoptions -p \(name)")
            guard optionsResult.stdout.contains("printer-is-shared=true") else { continue }

            let detailResult = ShellCommand.run("lpstat -l -p \(name)")
            let isAllUsers = detailResult.stdout.lowercased().contains("allowed users: all")
            if !isAllUsers {
                log("Printer \(name) is shared but not open to all users — fixing")
                ShellCommand.run("lpadmin -p \(name) -u allow:all")
                changed = true
            }
        }

        return changed
    }

    static func stripPPD(printerName: String, widthPoints: Int, heightPoints: Int, sizeLabel: String) -> Bool {
        let ppdPath = "\(ppdBasePath)/\(printerName).ppd"

        guard FileManager.default.fileExists(atPath: ppdPath) else {
            log("PPD not found at \(ppdPath)")
            return false
        }

        guard let content = try? String(contentsOfFile: ppdPath, encoding: .utf8) else {
            log("Failed to read PPD at \(ppdPath)")
            return false
        }

        let backupPath = ppdPath + ".original"
        if !FileManager.default.fileExists(atPath: backupPath) {
            ShellCommand.run("cp \(ppdPath) \(backupPath)")
            log("Backed up PPD to \(backupPath)")
        }

        let stripped = PPDStripper.strip(ppd: content, widthPoints: widthPoints, heightPoints: heightPoints, sizeLabel: sizeLabel)
        let tmpPath = ppdPath + ".tmp"

        do {
            try stripped.write(toFile: tmpPath, atomically: true, encoding: .utf8)
        } catch {
            log("Failed to write stripped PPD to \(tmpPath): \(error)")
            return false
        }

        ShellCommand.run("mv \(tmpPath) \(ppdPath)")
        log("Stripped PPD written for \(printerName)")
        restartCUPS()
        return true
    }

    static func restorePPD(printerName: String) {
        let ppdPath = "\(ppdBasePath)/\(printerName).ppd"
        let backupPath = ppdPath + ".original"

        guard FileManager.default.fileExists(atPath: backupPath) else {
            log("No .original backup found for \(printerName)")
            return
        }

        ShellCommand.run("cp \(backupPath) \(ppdPath)")
        log("Restored PPD for \(printerName) from backup")
        restartCUPS()
    }

    static func revertConfig() {
        let backupPath = configPath + ".bak"

        guard FileManager.default.fileExists(atPath: backupPath) else {
            log("No .bak backup found for cupsd.conf")
            return
        }

        ShellCommand.run("cp \(backupPath) \(configPath)")
        log("Reverted cupsd.conf from backup")
        restartCUPS()
    }

    static func restartCUPS() {
        log("Restarting CUPS via launchctl")
        ShellCommand.run("launchctl stop org.cups.cupsd")
        ShellCommand.run("launchctl start org.cups.cupsd")
    }
}
