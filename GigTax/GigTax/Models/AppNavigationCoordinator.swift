import Foundation
import Observation

/// Lets an App Intent (Siri/Shortcuts) tell the already-running or
/// freshly-launched app UI where to navigate, since intents run outside the
/// SwiftUI view hierarchy and have no direct way to push a sheet themselves.
/// ContentView observes `pendingDestination` and presents accordingly.
@Observable
final class AppNavigationCoordinator {
    static let shared = AppNavigationCoordinator()

    enum Destination: Identifiable {
        case logShift(platform: Platform?)

        var id: String {
            switch self {
            case .logShift: return "logShift"
            }
        }
    }

    var pendingDestination: Destination?
}
