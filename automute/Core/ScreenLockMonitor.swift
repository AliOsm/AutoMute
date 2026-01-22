import Foundation

final class ScreenLockMonitor {
    private var isMonitoring = false

    var onScreenLocked: (() -> Void)?
    var onScreenUnlocked: (() -> Void)?

    private(set) var isScreenLocked = false

    // MARK: - Public Methods

    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true

        // Listen for screen lock notification
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenLocked),
            name: .screenIsLocked,
            object: nil
        )

        // Listen for screen unlock notification
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(handleScreenUnlocked),
            name: .screenIsUnlocked,
            object: nil
        )
    }

    func stop() {
        guard isMonitoring else { return }
        isMonitoring = false

        DistributedNotificationCenter.default().removeObserver(
            self,
            name: .screenIsLocked,
            object: nil
        )

        DistributedNotificationCenter.default().removeObserver(
            self,
            name: .screenIsUnlocked,
            object: nil
        )
    }

    deinit {
        stop()
    }

    // MARK: - Private Methods

    @objc private func handleScreenLocked() {
        DispatchQueue.main.async { [weak self] in
            self?.isScreenLocked = true
            self?.onScreenLocked?()
        }
    }

    @objc private func handleScreenUnlocked() {
        DispatchQueue.main.async { [weak self] in
            self?.isScreenLocked = false
            self?.onScreenUnlocked?()
        }
    }
}
