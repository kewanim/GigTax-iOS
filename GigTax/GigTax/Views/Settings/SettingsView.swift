import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            Text("Settings coming in S6")
                .foregroundStyle(.secondary)
                .navigationTitle("Settings")
        }
    }
}

#Preview {
    SettingsView()
}
