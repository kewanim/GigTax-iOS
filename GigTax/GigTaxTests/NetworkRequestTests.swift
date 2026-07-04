import Testing
import Foundation
@testable import GigTax

struct NetworkRequestTests {

    @Test func timeoutIsShorterThanURLSessionDefault() {
        // URLSession's own default is 60s — this only matters if ours is
        // meaningfully shorter, so a real driver with spotty signal doesn't
        // wait a full minute to find out an API call failed.
        #expect(NetworkRequest.timeoutInterval < 60)
        #expect(NetworkRequest.timeoutInterval > 0)
    }
}
