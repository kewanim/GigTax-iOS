import SwiftUI

struct TripsView: View {
    var body: some View {
        NavigationStack {
            Text("Trip tracking coming in S2")
                .foregroundStyle(.secondary)
                .navigationTitle("Trips")
        }
    }
}

#Preview {
    TripsView()
}
