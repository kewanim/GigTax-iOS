import SwiftUI

struct CloudBackupView: View {
    @Environment(CloudSyncStatusService.self) private var syncStatus
    @State private var isRefreshing = false

    private var relativeSyncTime: String {
        guard let lastSyncDate = syncStatus.lastSyncDate else { return "Not yet synced" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastSyncDate, relativeTo: .now)
    }

    var body: some View {
        List {
            if syncStatus.accountDidChange {
                Section {
                    Label {
                        Text("The iCloud account signed into this device changed since GigTax last synced. If this wasn't you, your data may not match what you expect until this is resolved.")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    Button("Dismiss") { syncStatus.acknowledgeAccountChange() }
                } header: {
                    Text("Account Changed")
                }
            }

            Section {
                HStack {
                    statusIcon
                    VStack(alignment: .leading, spacing: 2) {
                        Text(syncStatus.accountState.summary)
                            .font(.subheadline).fontWeight(.semibold)
                        if let guidance = syncStatus.accountState.guidance {
                            Text(guidance)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .combine)

                LabeledContent("Last Synced", value: relativeSyncTime)

                if syncStatus.accountState == .noAccount || syncStatus.accountState == .restricted {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Label("Open Settings", systemImage: "gearshape")
                    }
                }
            } header: {
                Text("Backup Status")
            } footer: {
                Text("GigTax backs up automatically to whichever iCloud account is signed into this device — there's no separate GigTax account to create or log into. iCloud syncs opportunistically in the background; \"Check Now\" re-reads the current status but can't force a new sync.")
            }

            Section {
                Button {
                    Task { await refresh() }
                } label: {
                    if isRefreshing {
                        HStack {
                            ProgressView().controlSize(.small)
                            Text("Checking…")
                        }
                    } else {
                        Text("Check Now")
                    }
                }
                .disabled(isRefreshing)
            }
        }
        .navigationTitle("Backup & iCloud")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
    }

    @ViewBuilder
    private var statusIcon: some View {
        Group {
            switch syncStatus.accountState {
            case .checking:
                ProgressView()
            case .available:
                Image(systemName: "checkmark.icloud.fill").foregroundStyle(.green)
            case .noAccount, .restricted, .couldNotDetermine:
                Image(systemName: "exclamationmark.icloud.fill").foregroundStyle(.orange)
            case .temporarilyUnavailable:
                Image(systemName: "icloud.slash").foregroundStyle(.secondary)
            }
        }
        .font(.title2)
        .frame(width: 32)
    }

    private func refresh() async {
        isRefreshing = true
        await syncStatus.refresh()
        isRefreshing = false
    }
}

#Preview {
    NavigationStack {
        CloudBackupView()
            .environment(CloudSyncStatusService())
    }
}
