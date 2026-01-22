import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var engine: AutomuteEngine

    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .environmentObject(engine)

            BehaviorSettingsView()
                .tabItem {
                    Label("Behavior", systemImage: "speaker.wave.2")
                }
                .environmentObject(engine)

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 400, height: 250)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var engine: AutomuteEngine

    private let timeoutOptions = [1, 2, 3, 5, 10, 15, 30, 60]

    var body: some View {
        Form {
            Section {
                Toggle("Enable AutoMute", isOn: $engine.isEnabled)

                Toggle("Launch at Login", isOn: $engine.launchAtLogin)
            }

            Section {
                Picker("Inactivity Timeout", selection: $engine.inactivityMinutes) {
                    ForEach(timeoutOptions, id: \.self) { minutes in
                        Text(formatMinutes(minutes)).tag(minutes)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func formatMinutes(_ minutes: Int) -> String {
        if minutes == 1 {
            return "1 minute"
        } else if minutes < 60 {
            return "\(minutes) minutes"
        } else {
            return "1 hour"
        }
    }
}

// MARK: - Behavior Settings

struct BehaviorSettingsView: View {
    @EnvironmentObject var engine: AutomuteEngine

    var body: some View {
        Form {
            Section("Mute Triggers") {
                Toggle("Mute on Inactivity", isOn: $engine.muteOnInactivity)
                Toggle("Mute on Screen Lock", isOn: $engine.muteOnScreenLock)
            }

            Section("Unmute Behavior") {
                Toggle("Unmute on Activity", isOn: $engine.unmuteOnActivity)
                Toggle("Unmute on Screen Unlock", isOn: $engine.unmuteOnUnlock)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - About View

struct AboutView: View {
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "speaker.slash.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)

            Text("AutoMute")
                .font(.title)
                .fontWeight(.semibold)

            Text("Version \(appVersion) (\(buildNumber))")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("Automatically mutes your Mac when inactive or locked.")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AutomuteEngine())
}
