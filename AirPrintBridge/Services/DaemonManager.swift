import Foundation
import ServiceManagement

final class DaemonManager: ObservableObject {
    private let service: SMAppService

    var status: SMAppService.Status {
        service.status
    }

    var isRegistered: Bool {
        status == .enabled
    }

    var statusDescription: String {
        switch status {
        case .notRegistered: return "Niet geregistreerd"
        case .enabled: return "Actief"
        case .requiresApproval: return "Wacht op goedkeuring"
        case .notFound: return "Niet gevonden"
        @unknown default: return "Onbekend"
        }
    }

    init() {
        self.service = SMAppService.daemon(plistName: "\(AirPrintBridge.daemonLabel).plist")
    }

    func register() throws {
        try service.register()
    }

    func unregister() throws {
        try service.unregister()
    }
}
