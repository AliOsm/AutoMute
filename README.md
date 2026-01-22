# AutoMute

A lightweight macOS menu bar app that automatically mutes your system audio when your Mac is inactive or the screen is locked.

## Features

- **Inactivity Detection** — Automatically mutes audio after a configurable period of no keyboard/mouse activity
- **Screen Lock Detection** — Instantly mutes when you lock your screen (Cmd+Ctrl+Q)
- **Smart Unmute** — Optionally unmutes when you return or unlock
- **Respects Manual Mute** — If you muted before going idle, it won't unmute on return
- **Live Idle Timer** — See your current idle time in the menu bar popup
- **Launch at Login** — Start automatically when you log in
- **Native & Lightweight** — Pure Swift/SwiftUI, no external dependencies, minimal resource usage

## Requirements

- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac

## Installation

### Download

Download the latest release from the [Releases](https://github.com/aliosm/automute/releases) page.

### Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/aliosm/automute.git
   cd automute
   ```

2. Open in Xcode:
   ```bash
   open automute.xcodeproj
   ```

3. Build and run (Cmd+R)

## Usage

Once launched, AutoMute lives in your menu bar. Click the icon to:

- **Enable/Disable** — Toggle AutoMute on or off
- **Configure Triggers** — Choose whether to mute on inactivity, screen lock, or both
- **View Idle Time** — See how long you've been idle and the threshold

### Settings

Access settings via the menu bar popup or the Settings window:

| Setting | Description | Default |
|---------|-------------|---------|
| Enable AutoMute | Master on/off switch | On |
| Launch at Login | Start when you log in | Off |
| Inactivity Timeout | Minutes of idle time before muting | 5 min |
| Mute on Inactivity | Mute when idle threshold is reached | On |
| Mute on Screen Lock | Mute when screen locks | On |
| Unmute on Activity | Unmute when keyboard/mouse activity detected | On |
| Unmute on Screen Unlock | Unmute when screen unlocks | On |

## How It Works

AutoMute uses native macOS APIs with no special permissions required:

- **Idle Detection**: Uses `CGEventSource.secondsSinceLastEventType` to detect keyboard/mouse inactivity
- **Screen Lock Detection**: Listens to `com.apple.screenIsLocked` / `com.apple.screenIsUnlocked` distributed notifications
- **Audio Control**: Uses CoreAudio's `kAudioDevicePropertyMute` to mute/unmute the default output device
- **Device Changes**: Automatically handles audio device switches (e.g., connecting headphones)

### Edge Cases Handled

| Scenario | Behavior |
|----------|----------|
| You mute before going idle | Won't auto-unmute when you return |
| You unmute while auto-muted | Respects your choice, clears auto-mute state |
| Screen locks while idle-muted | Stays muted, updates reason to screen lock |
| Audio device changes while muted | Re-applies mute to new device |

## Privacy

AutoMute:
- Does **not** require any special permissions
- Does **not** collect any data
- Does **not** connect to the internet
- Stores preferences locally in UserDefaults

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development

The project structure:

```
automute/
├── App/
│   └── AutomuteApp.swift          # Main entry point
├── Core/
│   ├── AudioController.swift      # CoreAudio mute/unmute
│   ├── InactivityMonitor.swift    # Idle time detection
│   ├── ScreenLockMonitor.swift    # Lock/unlock detection
│   └── AutomuteEngine.swift       # Main orchestrator
├── Models/
│   ├── MuteReason.swift           # Why we muted
│   └── MonitoringState.swift      # Current app state
├── Views/
│   ├── MenuBarView.swift          # Menu bar popup
│   ├── SettingsView.swift         # Settings window
│   └── StatusIndicatorView.swift  # Status indicator
└── Extensions/
    └── Notification+Names.swift   # Notification constants
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with SwiftUI and CoreAudio
- Inspired by the need to not blast audio when returning to an unlocked Mac in public spaces
