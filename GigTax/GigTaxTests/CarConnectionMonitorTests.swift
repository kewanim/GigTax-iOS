import Testing
import AVFoundation
@testable import GigTax

struct CarConnectionMonitorTests {

    // GT-115: connecting to the car (CarPlay or Bluetooth car audio) prompts
    // a business/personal decision when no shift is running; disconnecting
    // prompts a shift's-over/break/still-going decision when one is.

    @Test func carPlayPortIsRecognizedAsCarConnected() {
        #expect(CarConnectionMonitor.isCarConnected(outputPortTypes: [.carAudio]) == true)
    }

    @Test func bluetoothCarAudioIsRecognizedAsCarConnectedToo() {
        #expect(CarConnectionMonitor.isCarConnected(outputPortTypes: [.bluetoothA2DP]) == true)
        #expect(CarConnectionMonitor.isCarConnected(outputPortTypes: [.bluetoothHFP]) == true)
    }

    @Test func builtInSpeakerIsNotCarConnected() {
        #expect(CarConnectionMonitor.isCarConnected(outputPortTypes: [.builtInSpeaker]) == false)
    }

    @Test func noPortsIsNotCarConnected() {
        #expect(CarConnectionMonitor.isCarConnected(outputPortTypes: []) == false)
    }

    @Test func goingFromDisconnectedToConnectedIsAConnectedEvent() {
        #expect(CarConnectionMonitor.evaluate(wasConnected: false, isConnectedNow: true) == .connected)
    }

    @Test func goingFromConnectedToDisconnectedIsADisconnectedEvent() {
        #expect(CarConnectionMonitor.evaluate(wasConnected: true, isConnectedNow: false) == .disconnected)
    }

    @Test func noChangeInConnectionStateIsNoEvent() {
        #expect(CarConnectionMonitor.evaluate(wasConnected: true, isConnectedNow: true) == .none)
        #expect(CarConnectionMonitor.evaluate(wasConnected: false, isConnectedNow: false) == .none)
    }

    @Test func connectingWithNoActiveShiftPromptsTheBusinessPersonalDecision() {
        #expect(CarConnectionMonitor.promptAction(for: .connected, isShiftActive: false) == .promptConnected)
    }

    @Test func connectingWithAnAlreadyActiveShiftPromptsNothing() {
        #expect(CarConnectionMonitor.promptAction(for: .connected, isShiftActive: true) == .none)
    }

    @Test func disconnectingWithAnActiveShiftPromptsTheEndPauseDecision() {
        #expect(CarConnectionMonitor.promptAction(for: .disconnected, isShiftActive: true) == .promptDisconnected)
    }

    @Test func disconnectingWithNoActiveShiftPromptsNothing() {
        #expect(CarConnectionMonitor.promptAction(for: .disconnected, isShiftActive: false) == .none)
    }
}
