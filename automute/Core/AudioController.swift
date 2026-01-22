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

    private var deviceChangeListenerBlock: AudioObjectPropertyListenerBlock?
    private var muteChangeListenerBlock: AudioObjectPropertyListenerBlock?
    private var currentDeviceID: AudioDeviceID = kAudioObjectUnknown

    var onMuteStateChanged: ((Bool) -> Void)?
    var onDeviceChanged: (() -> Void)?

    private init() {
        setupDeviceChangeListener()
        if let device = getDefaultOutputDevice() {
            currentDeviceID = device
            setupMuteChangeListener(for: device)
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

    private func handleDeviceChange() {
        if let newDevice = getDefaultOutputDevice() {
            setupMuteChangeListener(for: newDevice)
        }
        onDeviceChanged?()
        NotificationCenter.default.post(name: .audioDeviceChanged, object: nil)
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

        if currentDeviceID != kAudioObjectUnknown, let block = muteChangeListenerBlock {
            var propertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyMute,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(currentDeviceID, &propertyAddress, DispatchQueue.main, block)
        }
    }
}
