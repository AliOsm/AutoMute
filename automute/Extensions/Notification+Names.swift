import Foundation

extension Notification.Name {
    // Screen lock/unlock notifications (system distributed notifications)
    static let screenIsLocked = Notification.Name("com.apple.screenIsLocked")
    static let screenIsUnlocked = Notification.Name("com.apple.screenIsUnlocked")

    // Internal app notifications
    static let audioDeviceChanged = Notification.Name("com.aliosm.automute.audioDeviceChanged")
    static let muteStateChanged = Notification.Name("com.aliosm.automute.muteStateChanged")
}
