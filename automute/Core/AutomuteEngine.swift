import Foundation
import SwiftUI
import ServiceManagement

final class AutomuteEngine: ObservableObject {
    // MARK: - Published State

    @Published private(set) var state: MonitoringState = .active
    @Published private(set) var currentIdleTime: TimeInterval = 0

    // MARK: - Settings (persisted via AppStorage)

    @AppStorage("isEnabled") var isEnabled = true {
        didSet { handleEnabledChanged() }
    }

    @AppStorage("muteOnInactivity") var muteOnInactivity = true
    @AppStorage("muteOnScreenLock") var muteOnScreenLock = true
    @AppStorage("unmuteOnActivity") var unmuteOnActivity = true
    @AppStorage("unmuteOnUnlock") var unmuteOnUnlock = true

    @AppStorage("inactivityMinutes") var inactivityMinutes = 5 {
        didSet { inactivityMonitor.updateThreshold(minutes: inactivityMinutes) }
    }

    @AppStorage("launchAtLogin") var launchAtLogin = false {
        didSet { handleLaunchAtLoginChanged() }
    }

    // MARK: - Private State

    private var wasManuallyMutedBeforeAutoMute = false
    private var autoMuteReason: MuteReason?

    // MARK: - Dependencies

    private let audioController = AudioController.shared
    private let inactivityMonitor: InactivityMonitor
    private let screenLockMonitor = ScreenLockMonitor()

    // MARK: - Computed Properties

    var currentIcon: String {
        state.iconName
    }

    var idleProgressText: String {
        let currentMins = Int(currentIdleTime) / 60
        let currentSecs = Int(currentIdleTime) % 60
        return String(format: "%d:%02d / %dm", currentMins, currentSecs, inactivityMinutes)
    }

    // MARK: - Initialization

    init() {
        // Read from UserDefaults directly since @AppStorage isn't accessible yet
        let minutes = UserDefaults.standard.object(forKey: "inactivityMinutes") as? Int ?? 5
        inactivityMonitor = InactivityMonitor(thresholdMinutes: minutes)
        setupCallbacks()

        let enabled = UserDefaults.standard.object(forKey: "isEnabled") as? Bool ?? true
        if enabled {
            startMonitoring()
        } else {
            state = .disabled
        }
    }

    // MARK: - Public Methods

    func toggle() {
        isEnabled.toggle()
    }

    // MARK: - Private Methods

    private func setupCallbacks() {
        // Inactivity monitor callbacks
        inactivityMonitor.onIdleTimeUpdated = { [weak self] idleTime in
            self?.handleIdleTimeUpdated(idleTime)
        }

        inactivityMonitor.onInactivityThresholdReached = { [weak self] in
            self?.handleInactivityThresholdReached()
        }

        inactivityMonitor.onActivityDetected = { [weak self] in
            self?.handleActivityDetected()
        }

        // Screen lock monitor callbacks
        screenLockMonitor.onScreenLocked = { [weak self] in
            self?.handleScreenLocked()
        }

        screenLockMonitor.onScreenUnlocked = { [weak self] in
            self?.handleScreenUnlocked()
        }

        // Audio controller callbacks
        audioController.onMuteStateChanged = { [weak self] muted in
            self?.handleExternalMuteStateChange(muted)
        }

        audioController.onDeviceChanged = { [weak self] in
            self?.handleAudioDeviceChanged()
        }
    }

    private func startMonitoring() {
        inactivityMonitor.start()
        screenLockMonitor.start()
        state = .active
    }

    private func stopMonitoring() {
        inactivityMonitor.stop()
        screenLockMonitor.stop()
        state = .disabled
        currentIdleTime = 0
    }

    private func handleEnabledChanged() {
        if isEnabled {
            startMonitoring()
        } else {
            stopMonitoring()
        }
    }

    private func handleLaunchAtLoginChanged() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to update launch at login: \(error)")
        }
    }

    // MARK: - Event Handlers

    private func handleIdleTimeUpdated(_ idleTime: TimeInterval) {
        currentIdleTime = idleTime

        // Update state if we're not muted and not screen locked
        if autoMuteReason == nil && !screenLockMonitor.isScreenLocked {
            if idleTime > 0 {
                state = .idle(seconds: idleTime)
            } else {
                state = .active
            }
        }
    }

    private func handleInactivityThresholdReached() {
        guard isEnabled && muteOnInactivity else { return }
        guard autoMuteReason == nil else { return } // Already auto-muted

        // Check if user manually muted before we auto-mute
        wasManuallyMutedBeforeAutoMute = audioController.isMuted()

        if !wasManuallyMutedBeforeAutoMute {
            audioController.mute()
            autoMuteReason = .inactivity
            state = .muted(reason: .inactivity)
        }
    }

    private func handleActivityDetected() {
        guard isEnabled else { return }

        currentIdleTime = 0

        // Only unmute if we muted due to inactivity
        if autoMuteReason == .inactivity && unmuteOnActivity && !wasManuallyMutedBeforeAutoMute {
            audioController.unmute()
            clearAutoMuteState()
            state = .active
        } else if autoMuteReason != nil {
            // Still muted, keep showing muted state
            state = .muted(reason: autoMuteReason!)
        } else {
            state = .active
        }
    }

    private func handleScreenLocked() {
        guard isEnabled && muteOnScreenLock else {
            state = .screenLocked
            return
        }

        // If not already auto-muted, check manual mute state
        if autoMuteReason == nil {
            wasManuallyMutedBeforeAutoMute = audioController.isMuted()
        }

        if !wasManuallyMutedBeforeAutoMute {
            audioController.mute()
            autoMuteReason = .screenLock
        }

        state = .screenLocked
    }

    private func handleScreenUnlocked() {
        guard isEnabled else {
            state = .active
            return
        }

        // Only unmute if we muted due to screen lock
        if autoMuteReason == .screenLock && unmuteOnUnlock && !wasManuallyMutedBeforeAutoMute {
            audioController.unmute()
            clearAutoMuteState()
        } else if autoMuteReason == .inactivity {
            // Keep muted state if we were muted due to inactivity
            state = .muted(reason: .inactivity)
            return
        }

        state = .active
    }

    private func handleExternalMuteStateChange(_ muted: Bool) {
        // User manually changed mute state while we have auto-muted
        if autoMuteReason != nil && !muted {
            // User unmuted manually, clear our tracking
            clearAutoMuteState()
        }
    }

    private func handleAudioDeviceChanged() {
        // Re-apply mute if we're in auto-mute state
        if autoMuteReason != nil && !wasManuallyMutedBeforeAutoMute {
            audioController.mute()
        }
    }

    private func clearAutoMuteState() {
        autoMuteReason = nil
        wasManuallyMutedBeforeAutoMute = false
    }
}
