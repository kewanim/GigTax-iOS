import AppIntents
import Foundation

/// "Log a shift" — opens GigTax straight to the manual shift entry form,
/// pre-filled with whatever platform the driver last logged a shift under.
/// The last-used platform is cached in UserDefaults (written whenever a
/// shift is saved) rather than fetched from SwiftData here, since it's a
/// cheap, always-available value and this intent shouldn't need to wait on
/// a full model fetch just to guess a starting platform.
struct LogShiftIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a Shift"
    static var description = IntentDescription("Opens GigTax to log a new shift, pre-filled with your last used platform.")
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        let lastPlatformRaw = UserDefaults.standard.string(forKey: LastUsedPlatformStore.key)
        let lastPlatform = lastPlatformRaw.flatMap { Platform(rawValue: $0) }
        AppNavigationCoordinator.shared.pendingDestination = .logShift(platform: lastPlatform)
        return .result()
    }
}

/// Shared read/write point for the "last used platform" cache — kept as
/// its own tiny type so both the intent and the shift-saving code reference
/// the same UserDefaults key without hardcoding a string in two places.
enum LastUsedPlatformStore {
    static let key = "lastUsedPlatform"

    static func record(_ platform: Platform) {
        UserDefaults.standard.set(platform.rawValue, forKey: key)
    }
}
