import Testing
import Foundation
@testable import GigTax

@Suite(.serialized)
struct LastUsedPlatformStoreTests {

    @Test func recordsAndReadsBackThePlatform() {
        LastUsedPlatformStore.record(.doorDash)
        let stored = UserDefaults.standard.string(forKey: LastUsedPlatformStore.key)
        #expect(stored == Platform.doorDash.rawValue)
    }

    @Test func overwritesThePreviousValue() {
        LastUsedPlatformStore.record(.uber)
        LastUsedPlatformStore.record(.lyft)
        let stored = UserDefaults.standard.string(forKey: LastUsedPlatformStore.key)
        #expect(stored == Platform.lyft.rawValue)
    }
}
