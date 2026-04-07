import SwiftUI

@main
struct AirPrintBridgeApp: App {
    @StateObject private var config = BridgeConfig()

    var body: some Scene {
        MenuBarExtra(
            "AirPrint Bridge",
            systemImage: "printer.fill",
            isInserted: $config.showMenuBarIcon
        ) {
            PopoverView()
                .environmentObject(config)
        }
        .menuBarExtraStyle(.window)

        Settings {
            TabView {
                SettingsGeneralView()
                    .tabItem {
                        Label("Algemeen", systemImage: "gear")
                    }
                SettingsPrintersView()
                    .tabItem {
                        Label("Printers", systemImage: "printer")
                    }
            }
            .environmentObject(config)
        }
    }
}
