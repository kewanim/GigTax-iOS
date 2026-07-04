import ActivityKit
import WidgetKit
import SwiftUI

struct TripLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            // Lock Screen / banner presentation
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trip in Progress")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(context.state.miles, specifier: "%.1f") mi")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Est. Fuel")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(context.state.estimatedFuelCost, format: .currency(code: "USD"))
                        .font(.headline)
                }
            }
            .padding()
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text("Trip").font(.caption2).foregroundStyle(.secondary)
                        Text("\(context.state.miles, specifier: "%.1f") mi").font(.headline)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("Fuel").font(.caption2).foregroundStyle(.secondary)
                        Text(context.state.estimatedFuelCost, format: .currency(code: "USD")).font(.headline)
                    }
                }
            } compactLeading: {
                Image(systemName: "car.fill")
            } compactTrailing: {
                Text("\(context.state.miles, specifier: "%.0f")mi")
            } minimal: {
                Image(systemName: "car.fill")
            }
        }
    }
}
