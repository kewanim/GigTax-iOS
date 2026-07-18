import CloudKit
import Foundation
import CoreData
import Observation

/// Surfaces the CloudKit account/sync state that GT-008's automatic SwiftData
/// sync has always run silently without any UI. There is no public API to
/// force a new CloudKit sync — sync is system-scheduled around remote-change
/// notifications and app-foreground events — so "last synced" here means the
/// most recent sync SwiftData's underlying NSPersistentCloudKitContainer
/// actually reported via its notification, not something this service can
/// trigger on demand. Persisted across launches so the driver isn't staring
/// at a blank "no sync yet" the moment they open the app.
@Observable
final class CloudSyncStatusService {
    enum AccountState: Equatable {
        case checking
        case available
        case noAccount
        case restricted
        case temporarilyUnavailable
        case couldNotDetermine

        var summary: String {
            switch self {
            case .checking: "Checking iCloud status…"
            case .available: "Backing up to iCloud"
            case .noAccount: "Not signed into iCloud"
            case .restricted: "iCloud access restricted"
            case .temporarilyUnavailable: "iCloud temporarily unavailable"
            case .couldNotDetermine: "Couldn't check iCloud status"
            }
        }

        var guidance: String? {
            switch self {
            case .available, .checking: nil
            case .noAccount: "Sign into iCloud in Settings to back up your GigTax data."
            case .restricted: "iCloud access is restricted on this device (Screen Time or a configuration profile). Backup is unavailable until that changes."
            case .temporarilyUnavailable: "iCloud is temporarily unavailable. This usually resolves on its own — try again shortly."
            case .couldNotDetermine: "Check your network connection and try again."
            }
        }

        var isHealthy: Bool { self == .available }
    }

    private static let lastSyncDateKey = "cloudSyncStatus.lastSyncDate"
    private static let lastKnownAccountKey = "cloudSyncStatus.lastKnownAccount"

    private(set) var accountState: AccountState = .checking
    private(set) var lastSyncDate: Date?
    private(set) var accountDidChange = false

    private var eventObserver: NSObjectProtocol?
    private let container: CKContainer

    init(containerIdentifier: String = "iCloud.com.kewani-is-th.GigTax") {
        container = CKContainer(identifier: containerIdentifier)
        if let stored = UserDefaults.standard.object(forKey: Self.lastSyncDateKey) as? Date {
            lastSyncDate = stored
        }
        observeSyncEvents()
    }

    deinit {
        if let eventObserver {
            NotificationCenter.default.removeObserver(eventObserver)
        }
    }

    @MainActor
    func refresh() async {
        accountState = .checking
        do {
            let status = try await container.accountStatus()
            accountState = Self.map(status)
        } catch {
            accountState = .couldNotDetermine
        }
        checkForAccountChange()
    }

    /// iCloud tokens change identity when the signed-in account changes account
    /// on the same device (not just sign-out/sign-in) — this is the documented
    /// way to detect that CloudKit-relevant state should be treated as stale.
    private func checkForAccountChange() {
        let currentToken = FileManager.default.ubiquityIdentityToken
        let currentDescription = currentToken.map { String(describing: $0) }
        let lastKnown = UserDefaults.standard.string(forKey: Self.lastKnownAccountKey)

        if let lastKnown, let currentDescription, lastKnown != currentDescription {
            accountDidChange = true
        }
        if let currentDescription {
            UserDefaults.standard.set(currentDescription, forKey: Self.lastKnownAccountKey)
        }
    }

    func acknowledgeAccountChange() {
        accountDidChange = false
    }

    private func observeSyncEvents() {
        eventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self,
                  let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] as? NSPersistentCloudKitContainer.Event,
                  event.endDate != nil,
                  event.succeeded else { return }
            let date = Date()
            self.lastSyncDate = date
            UserDefaults.standard.set(date, forKey: Self.lastSyncDateKey)
        }
    }

    private static func map(_ status: CKAccountStatus) -> AccountState {
        switch status {
        case .available: .available
        case .noAccount: .noAccount
        case .restricted: .restricted
        case .temporarilyUnavailable: .temporarilyUnavailable
        case .couldNotDetermine: .couldNotDetermine
        @unknown default: .couldNotDetermine
        }
    }
}
