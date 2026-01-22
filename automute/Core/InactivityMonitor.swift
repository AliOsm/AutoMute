import Foundation
import CoreGraphics

final class InactivityMonitor {
    private var timer: Timer?
    private var thresholdSeconds: TimeInterval
    private var wasIdle = false

    var onInactivityThresholdReached: (() -> Void)?
    var onActivityDetected: (() -> Void)?
    var onIdleTimeUpdated: ((TimeInterval) -> Void)?

    init(thresholdMinutes: Int = 5) {
        self.thresholdSeconds = TimeInterval(thresholdMinutes * 60)
    }

    deinit {
        stop()
    }

    // MARK: - Public Methods

    func start() {
        stop()
        timer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            self?.checkIdleTime()
        }
        timer?.tolerance = 0.5 // Energy efficiency
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        wasIdle = false
    }

    func updateThreshold(minutes: Int) {
        thresholdSeconds = TimeInterval(minutes * 60)
    }

    func getCurrentIdleTime() -> TimeInterval {
        // Get seconds since last keyboard/mouse event
        // Using ~0 (all bits set) captures all event types
        let idleTime = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: CGEventType(rawValue: ~0)!
        )
        return idleTime
    }

    // MARK: - Private Methods

    private func checkIdleTime() {
        let idleTime = getCurrentIdleTime()

        // Notify about current idle time for UI updates
        onIdleTimeUpdated?(idleTime)

        if idleTime >= thresholdSeconds {
            if !wasIdle {
                wasIdle = true
                onInactivityThresholdReached?()
            }
        } else {
            if wasIdle {
                wasIdle = false
                onActivityDetected?()
            }
        }
    }
}
