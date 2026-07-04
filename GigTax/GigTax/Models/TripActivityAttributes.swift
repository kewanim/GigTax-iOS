import ActivityKit
import Foundation

/// Shared between the main app (which starts/updates/ends the Live
/// Activity as a trip progresses) and the widget extension (which renders
/// its Dynamic Island / Lock Screen presentation) — both targets need this
/// exact type compiled in, since ActivityKit uses it to match the running
/// Activity to its UI.
struct TripActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var miles: Double
        var estimatedFuelCost: Double
    }

    var startDate: Date
}
