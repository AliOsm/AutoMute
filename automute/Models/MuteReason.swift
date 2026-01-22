import Foundation

/// Represents the reason why the system audio was automatically muted
enum MuteReason: String, Codable {
    case inactivity
    case screenLock

    var displayName: String {
        switch self {
        case .inactivity:
            return "Inactivity"
        case .screenLock:
            return "Screen Lock"
        }
    }
}
