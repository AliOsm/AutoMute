import SwiftUI

@main
struct AutomuteApp: App {
    @StateObject private var engine = AutomuteEngine()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(engine)
        } label: {
            Label("AutoMute", systemImage: engine.currentIcon)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(engine)
        }
    }
}
