import Testing
@testable import GigTax

struct EIAServiceTests {

    // The real bug a driver found in the field: gasPrice was permanently
    // stuck at a flat $3.45 for every state because EIAService was never
    // actually called anywhere. These confirm the fallback is now genuinely
    // state-specific rather than one flat number, without needing an API key.

    @Test func knownStateWithNoAPIKeyReturnsItsOwnEstimate() async {
        let result = await EIAService.shared.fetchGasPrice(state: "MD", apiKey: nil)
        #expect(result.isLive == false)
        #expect(abs(result.pricePerGallon - 3.989) < 0.001)
        #expect(result.regionName.contains("MD"))
    }

    @Test func differentStatesGetDifferentEstimates() async {
        let california = await EIAService.shared.fetchGasPrice(state: "CA", apiKey: nil)
        let texas = await EIAService.shared.fetchGasPrice(state: "TX", apiKey: nil)
        #expect(california.pricePerGallon != texas.pricePerGallon)
        // Real-world sanity: CA has consistently been among the most
        // expensive states for gas, TX among the cheapest.
        #expect(california.pricePerGallon > texas.pricePerGallon)
    }

    @Test func unrecognizedStateCodeFallsBackToNationalAverageNotAFlatOldConstant() async {
        let result = await EIAService.shared.fetchGasPrice(state: "ZZ", apiKey: nil)
        #expect(result.isLive == false)
        #expect(result.pricePerGallon != 3.45)  // the old, permanently-stuck fallback
        #expect(result.regionName.contains("National"))
    }

    @Test func emptyAPIKeyStringIsTreatedTheSameAsNoKey() async {
        let result = await EIAService.shared.fetchGasPrice(state: "MD", apiKey: "")
        #expect(result.isLive == false)
    }
}
