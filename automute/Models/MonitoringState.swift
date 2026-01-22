import Foundation

/// Represents the current state of the automute monitoring system
enum MonitoringState: Equatable {
    case disabled
    case active
    case idle(seconds: TimeInterval)
    case muted(reason: MuteReason)
    case screenLocked

    var statusText: String {
        switch self {
        case .disabled:
            return "Disabled"
        case .active:
            return "Active"
        case .idle(let seconds):
            return "Idle (\(formatTime(seconds)))"
        case .muted(let reason):
            return "Muted (\(reason.displayName))"
        case .screenLocked:
            return "Screen Locked"
        }
    }

    var statusColor: StatusColor {
        switch self {
        case .disabled:
            return .gray
        case .active:
            return .green
        case .idle:
            return .orange
        case .muted, .screenLocked:
            return .red
        }
    }

    var iconName: String {
        switch self {
        case .disabled:
            return "speaker.slash"
        case .active:
            return "speaker.wave.2.fill"
        case .idle:
            return "speaker.wave.2"
        case .muted:
            return "speaker.slash.fill"
        case .screenLocked:
            return "lock.fill"
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

enum StatusColor {
    case green
    case orange
    case red
    case gray
}
