import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            Text("Dashboard coming in S4")
                .foregroundStyle(.secondary)
                .navigationTitle("Dashboard")
        }
    }
}

#Preview {
    DashboardView()
}
