import Foundation

enum FirewallManager {
    private static let socketfilterfw = "/usr/libexec/ApplicationFirewall/socketfilterfw"

    private static func log(_ message: String) {
        print("[FirewallManager] \(message)")
    }

    // MARK: - Public API

    static func ensureCUPSAllowed() {
        let globalState = ShellCommand.run("\(socketfilterfw) --getglobalstate")
        guard globalState.stdout.lowercased().contains("enabled") else {
            log("Firewall is not enabled — no action needed")
            return
        }

        log("Firewall is enabled — checking cupsd")

        // Resolve cupsd path
        var cupsdPath = ShellCommand.run("which cupsd").stdout
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if cupsdPath.isEmpty {
            cupsdPath = "/usr/sbin/cupsd"
        }

        log("Using cupsd at \(cupsdPath)")

        let listApps = ShellCommand.run("\(socketfilterfw) --listapps")
        if listApps.stdout.contains(cupsdPath) {
            log("cupsd is already listed in firewall — no action needed")
            return
        }

        log("cupsd not listed in firewall — adding and unblocking")
        ShellCommand.run("\(socketfilterfw) --add \(cupsdPath)")
        ShellCommand.run("\(socketfilterfw) --unblockapp \(cupsdPath)")
        log("cupsd added and unblocked in firewall")
    }
}
