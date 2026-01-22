import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var engine: AutomuteEngine

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with status
            headerSection

            Divider()
                .padding(.vertical, 8)

            // Controls
            controlsSection

            Divider()
                .padding(.vertical, 8)

            // Idle time display
            if engine.isEnabled {
                idleTimeSection
                Divider()
                    .padding(.vertical, 8)
            }

            // Footer buttons
            footerSection
        }
        .padding(12)
        .frame(width: 260)
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("AutoMute")
                    .font(.headline)
                Spacer()
                StatusIndicatorView(state: engine.state)
            }
        }
    }

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Enabled", isOn: $engine.isEnabled)
                .toggleStyle(.switch)

            if engine.isEnabled {
                Toggle("Mute on Inactivity", isOn: $engine.muteOnInactivity)
                    .toggleStyle(.switch)
                    .padding(.leading, 8)

                Toggle("Mute on Screen Lock", isOn: $engine.muteOnScreenLock)
                    .toggleStyle(.switch)
                    .padding(.leading, 8)
            }
        }
    }

    private var idleTimeSection: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundColor(.secondary)
            Text("Idle:")
                .foregroundColor(.secondary)
            Spacer()
            Text(engine.idleProgressText)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
        }
    }

    private var footerSection: some View {
        HStack {
            settingsButton

            Spacer()

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private var settingsButton: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                Label("Settings", systemImage: "gear")
            }
            .buttonStyle(.borderless)
        } else {
            Button(action: {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }) {
                Label("Settings", systemImage: "gear")
            }
            .buttonStyle(.borderless)
        }
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AutomuteEngine())
}
