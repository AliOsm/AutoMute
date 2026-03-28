import Foundation
import CoreAudio

enum AudioError: Error, LocalizedError {
    case noDefaultDevice
    case getPropertyFailed(OSStatus)
    case setPropertyFailed(OSStatus)
    case deviceNotSupported

    var errorDescription: String? {
        switch self {
        case .noDefaultDevice:
            return "No default audio output device found"
        case .getPropertyFailed(let status):
            return "Failed to get audio property (error: \(status))"
        case .setPropertyFailed(let status):
            return "Failed to set audio property (error: \(status))"
        case .deviceNotSupported:
            return "Audio device does not support mute control"
        }
    }
}

final class AudioController {
    static let shared = AudioController()

    // Output device listeners
    private var deviceChangeListenerBlock: AudioObjectPropertyListenerBlock?
    private var muteChangeListenerBlock: AudioObjectPropertyListenerBlock?
    private var outputActivityListenerBlock: AudioObjectPropertyListenerBlock?
    private var currentDeviceID: AudioDeviceID = kAudioObjectUnknown

    // Input device listeners
    private var inputDeviceChangeListenerBlock: AudioObjectPropertyListenerBlock?
    private var inputActivityListenerBlock: AudioObjectPropertyListenerBlock?
    private var currentInputDeviceID: AudioDeviceID = kAudioObjectUnknown

    var onMuteStateChanged: ((Bool) -> Void)?
    var onDeviceChanged: (() -> Void)?
    var onAudioActivityChanged: (() -> Void)?
    var onInputActivityChanged: (() -> Void)?

    private init() {
        setupDeviceChangeListener()
        setupInputDeviceChangeListener()
        if let device = getDefaultOutputDevice() {
            currentDeviceID = device
            setupMuteChangeListener(for: device)
            setupOutputActivityListener(for: device)
        }
        if let inputDevice = getDefaultInputDevice() {
            currentInputDeviceID = inputDevice
            setupInputActivityListener(for: inputDevice)
        }
    }

    deinit {
        removeListeners()
    }

    // MARK: - Public Methods

    func getDefaultOutputDevice() -> AudioDeviceID? {
        var deviceID = kAudioObjectUnknown
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )

        guard status == noErr, deviceID != kAudioObjectUnknown else {
            return nil
        }

        return deviceID
    }

    func getDefaultInputDevice() -> AudioDeviceID? {
        var deviceID = kAudioObjectUnknown
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &deviceID
        )

        guard status == noErr, deviceID != kAudioObjectUnknown else {
            return nil
        }

        return deviceID
    }

    func isAudioOutputActive() -> Bool {
        guard let deviceID = getDefaultOutputDevice() else { return false }
        return isDeviceRunning(deviceID)
    }

    func isAudioInputActive() -> Bool {
        guard let deviceID = getDefaultInputDevice() else { return false }
        return isDeviceRunning(deviceID)
    }

    func getMuteState() -> Result<Bool, AudioError> {
        guard let deviceID = getDefaultOutputDevice() else {
            return .failure(.noDefaultDevice)
        }

        var muted: UInt32 = 0
        var propertySize = UInt32(MemoryLayout<UInt32>.size)

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        // Check if mute property is supported
        guard AudioObjectHasProperty(deviceID, &propertyAddress) else {
            return .failure(.deviceNotSupported)
        }

        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &muted
        )

        guard status == noErr else {
            return .failure(.getPropertyFailed(status))
        }

        return .success(muted != 0)
    }

    func setMuteState(_ muted: Bool) -> Result<Void, AudioError> {
        guard let deviceID = getDefaultOutputDevice() else {
            return .failure(.noDefaultDevice)
        }

        var mutedValue: UInt32 = muted ? 1 : 0
        let propertySize = UInt32(MemoryLayout<UInt32>.size)

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        // Check if mute property is supported and settable
        guard AudioObjectHasProperty(deviceID, &propertyAddress) else {
            return .failure(.deviceNotSupported)
        }

        var isSettable: DarwinBoolean = false
        let settableStatus = AudioObjectIsPropertySettable(deviceID, &propertyAddress, &isSettable)
        guard settableStatus == noErr, isSettable.boolValue else {
            return .failure(.deviceNotSupported)
        }

        let status = AudioObjectSetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            propertySize,
            &mutedValue
        )

        guard status == noErr else {
            return .failure(.setPropertyFailed(status))
        }

        return .success(())
    }

    func isMuted() -> Bool {
        switch getMuteState() {
        case .success(let muted):
            return muted
        case .failure:
            return false
        }
    }

    func mute() {
        _ = setMuteState(true)
    }

    func unmute() {
        _ = setMuteState(false)
    }

    // MARK: - Private Methods

    private func setupDeviceChangeListener() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        deviceChangeListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.handleDeviceChange()
            }
        }

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main,
            deviceChangeListenerBlock!
        )
    }

    private func setupMuteChangeListener(for deviceID: AudioDeviceID) {
        // Remove existing listener if any
        if currentDeviceID != kAudioObjectUnknown, let block = muteChangeListenerBlock {
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(currentDeviceID, &propertyAddress, DispatchQueue.main, block)
        }

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectHasProperty(deviceID, &propertyAddress) else {
            return
        }

        muteChangeListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                if let muted = try? self?.getMuteState().get() {
                    self?.onMuteStateChanged?(muted)
                }
            }
        }

        AudioObjectAddPropertyListenerBlock(
            deviceID,
            &propertyAddress,
            DispatchQueue.main,
            muteChangeListenerBlock!
        )

        currentDeviceID = deviceID
    }

    private func isDeviceRunning(_ deviceID: AudioDeviceID) -> Bool {
        var isRunning: UInt32 = 0
        var propertySize = UInt32(MemoryLayout<UInt32>.size)

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            deviceID,
            &propertyAddress,
            0,
            nil,
            &propertySize,
            &isRunning
        )

        guard status == noErr else { return false }
        return isRunning != 0
    }

    private func setupOutputActivityListener(for deviceID: AudioDeviceID) {
        // Remove existing listener if any
        removeOutputActivityListener()

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectHasProperty(deviceID, &propertyAddress) else { return }

        outputActivityListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.onAudioActivityChanged?()
            }
        }

        AudioObjectAddPropertyListenerBlock(
            deviceID,
            &propertyAddress,
            DispatchQueue.main,
            outputActivityListenerBlock!
        )
    }

    private func setupInputDeviceChangeListener() {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        inputDeviceChangeListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.handleInputDeviceChange()
            }
        }

        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            DispatchQueue.main,
            inputDeviceChangeListenerBlock!
        )
    }

    private func setupInputActivityListener(for deviceID: AudioDeviceID) {
        // Remove existing listener if any
        removeInputActivityListener()

        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard AudioObjectHasProperty(deviceID, &propertyAddress) else { return }

        inputActivityListenerBlock = { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.onInputActivityChanged?()
            }
        }

        AudioObjectAddPropertyListenerBlock(
            deviceID,
            &propertyAddress,
            DispatchQueue.main,
            inputActivityListenerBlock!
        )

        currentInputDeviceID = deviceID
    }

    private func handleDeviceChange() {
        if let newDevice = getDefaultOutputDevice() {
            setupMuteChangeListener(for: newDevice)
            setupOutputActivityListener(for: newDevice)
        }
        onDeviceChanged?()
        NotificationCenter.default.post(name: .audioDeviceChanged, object: nil)
    }

    private func handleInputDeviceChange() {
        if let newDevice = getDefaultInputDevice() {
            setupInputActivityListener(for: newDevice)
        }
    }

    private func removeOutputActivityListener() {
        if currentDeviceID != kAudioObjectUnknown, let block = outputActivityListenerBlock {
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(currentDeviceID, &propertyAddress, DispatchQueue.main, block)
            outputActivityListenerBlock = nil
        }
    }

    private func removeInputActivityListener() {
        if currentInputDeviceID != kAudioObjectUnknown, let block = inputActivityListenerBlock {
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(currentInputDeviceID, &propertyAddress, DispatchQueue.main, block)
            inputActivityListenerBlock = nil
        }
    }

    private func removeListeners() {
        if let block = deviceChangeListenerBlock {
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &propertyAddress,
                DispatchQueue.main,
                block
            )
        }

        if let block = inputDeviceChangeListenerBlock {
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &propertyAddress,
                DispatchQueue.main,
                block
            )
        }

        if currentDeviceID != kAudioObjectUnknown, let block = muteChangeListenerBlock {
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(currentDeviceID, &propertyAddress, DispatchQueue.main, block)
        }

        removeOutputActivityListener()
        removeInputActivityListener()
    }
}
