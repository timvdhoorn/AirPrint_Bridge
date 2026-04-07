import SwiftUI

@main
struct AirPrintBridgeApp: App {
    var body: some Scene {
        MenuBarExtra("AirPrint Bridge", systemImage: "printer.fill") {
            Text("AirPrint Bridge")
                .padding()
        }
        .menuBarExtraStyle(.window)

        Settings {
            Text("Instellingen")
                .padding()
        }
    }
}
