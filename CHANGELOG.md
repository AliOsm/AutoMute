# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [2.0] - 2026-03-28

### Added

- Audio activity detection: skip idle mute when audio is playing or microphone is in use
- New "Idle - Audio Active" state with blue indicator in menu bar
- Two new settings: "Don't mute when audio is playing" and "Don't mute when microphone is in use" (both enabled by default)
- CoreAudio listeners for real-time audio stream activity on both input and output devices
- Input device change tracking (re-attaches listeners when default mic changes)

### Changed

- Inactivity mute now checks for active audio streams before muting
- When audio stops during idle suppression, mute triggers immediately without restarting the timer
- Screen lock mute behavior unchanged (always mutes regardless of audio activity)
- Settings window height increased to accommodate new Audio Activity section

## [1.0] - 2026-01-22

### Added

- Initial release of AutoMute
- Automatic muting when Mac is inactive for a configurable period (1-60 minutes)
- Automatic muting when screen is locked
- Smart unmute on activity detection or screen unlock
- Manual mute detection (won't auto-unmute if you muted before going idle)
- Live idle timer display in menu bar popup
- Launch at Login support
- Settings window with General, Behavior, and About tabs
- Menu bar icon that reflects current state (active, muted, locked)
