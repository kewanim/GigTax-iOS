import SwiftUI

struct LockScreenView: View {
    let lockService: BiometricLockService

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "lock.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("GigTax is Locked")
                    .font(.title2)
                    .fontWeight(.semibold)
                Button("Unlock") {
                    Task { await lockService.authenticate() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .task {
            await lockService.authenticate()
        }
    }
}

#Preview {
    LockScreenView(lockService: BiometricLockService())
}
