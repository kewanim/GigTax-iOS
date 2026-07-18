import Testing
@testable import GigTax

@MainActor
struct CloudSyncStatusServiceTests {

    @Test func availableStateHasNoGuidanceAndIsHealthy() {
        let state = CloudSyncStatusService.AccountState.available
        #expect(state.guidance == nil)
        #expect(state.isHealthy == true)
        #expect(state.summary == "Backing up to iCloud")
    }

    @Test func noAccountStateExplainsHowToSignIn() {
        let state = CloudSyncStatusService.AccountState.noAccount
        #expect(state.isHealthy == false)
        #expect(state.guidance?.contains("Settings") == true)
    }

    @Test func restrictedStateIsNotHealthyAndExplainsWhy() {
        let state = CloudSyncStatusService.AccountState.restricted
        #expect(state.isHealthy == false)
        #expect(state.guidance != nil)
    }

    @Test func checkingStateHasNoGuidance() {
        let state = CloudSyncStatusService.AccountState.checking
        #expect(state.guidance == nil)
        #expect(state.isHealthy == false)
    }

    @Test func everyNonAvailableStateHasGuidanceExceptChecking() {
        let states: [CloudSyncStatusService.AccountState] = [.noAccount, .restricted, .temporarilyUnavailable, .couldNotDetermine]
        for state in states {
            #expect(state.guidance != nil, "\(state) should explain what the driver can do")
        }
    }
}
