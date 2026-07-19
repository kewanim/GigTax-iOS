import AVFoundation

/// Pure decision logic for the "connected/disconnected from the car" prompts —
/// kept separate from the real AVAudioSession/UNUserNotificationCenter calls
/// (which LocationService makes) so the actual decisions can be unit tested
/// without touching real system audio/notification APIs.
enum CarConnectionMonitor {
    enum Event {
        case connected
        case disconnected
        case none
    }

    /// CarPlay's own port type, plus generic Bluetooth car audio/hands-free —
    /// broader coverage for cars without CarPlay, at the cost of also firing
    /// for a Bluetooth speaker or headphones that aren't the car.
    static let carPortTypes: Set<AVAudioSession.Port> = [.carAudio, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE]

    static func isCarConnected(outputPortTypes: [AVAudioSession.Port]) -> Bool {
        outputPortTypes.contains { carPortTypes.contains($0) }
    }

    static func evaluate(wasConnected: Bool, isConnectedNow: Bool) -> Event {
        guard wasConnected != isConnectedNow else { return .none }
        return isConnectedNow ? .connected : .disconnected
    }

    enum PromptAction {
        case none
        case promptConnected
        case promptDisconnected
    }

    /// Connecting while a shift's already active has nothing to ask (it's
    /// already tagging business); disconnecting with no shift running has
    /// nothing to ask either (there's no shift to end/pause).
    static func promptAction(for event: Event, isShiftActive: Bool) -> PromptAction {
        switch event {
        case .connected:
            return isShiftActive ? .none : .promptConnected
        case .disconnected:
            return isShiftActive ? .promptDisconnected : .none
        case .none:
            return .none
        }
    }
}
