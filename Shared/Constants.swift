import Foundation

enum AirPrintBridge {
    static let suiteName = "nl.labelsenmeer.airprint-bridge.shared"
    static let daemonLabel = "nl.labelsenmeer.airprint-bridge.daemon"
    static let pidFilePath = "/var/run/airprint-bridge.pid"
    static let statusFilePath = "/tmp/airprint-bridge-status.json"
    static let cupsConfigPath = "/etc/cups/cupsd.conf"
    static let ppdBasePath = "/etc/cups/ppd"
    static let service = "_ipp._tcp.,_universal"
    static let domain = "local"
    static let reloadNotification = "nl.labelsenmeer.airprint-bridge.reload"
}
