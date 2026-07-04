import Foundation
import LocalAuthentication
import Observation

/// Locks the app when it goes to the background and requires Face ID/Touch
/// ID (with automatic passcode fallback) to unlock — `.deviceOwnerAuthentication`
/// covers both biometrics and passcode in one policy, so there's no separate
/// fallback path to write.
@Observable
final class BiometricLockService {
    var isLocked = false

    func lock() {
        isLocked = true
    }

    @discardableResult
    func authenticate(reason: String = "Unlock GigTax") async -> Bool {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            // No biometrics or passcode configured on this device at all —
            // there's nothing to authenticate against, so don't lock the
            // driver out of their own data over a device configuration gap.
            isLocked = false
            return true
        }

        do {
            let success = try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)
            if success {
                isLocked = false
            }
            return success
        } catch {
            return false
        }
    }
}
