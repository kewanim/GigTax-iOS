import Foundation

// EIA (Energy Information Administration) — free weekly gas price data
// Sign up for a free key at: https://www.eia.gov/opendata/register.php
// Add your key to Settings → API Keys once you have one.
// Falls back to a national average until a key is configured.

struct EIAGasPrice {
    let pricePerGallon: Double
    let regionName: String
    let weekOf: String
    let isLive: Bool
}

// Mapping from US state code to EIA padd region series ID for regular gasoline
private let stateToEIASeries: [String: String] = [
    "CT": "EMD_EPD2D_PTE_R10_DPG", "ME": "EMD_EPD2D_PTE_R10_DPG",
    "MA": "EMD_EPD2D_PTE_R10_DPG", "NH": "EMD_EPD2D_PTE_R10_DPG",
    "RI": "EMD_EPD2D_PTE_R10_DPG", "VT": "EMD_EPD2D_PTE_R10_DPG",
    "DE": "EMD_EPD2D_PTE_R1Y_DPG", "MD": "EMD_EPD2D_PTE_R1Y_DPG",
    "NJ": "EMD_EPD2D_PTE_R1Y_DPG", "NY": "EMD_EPD2D_PTE_R1Y_DPG",
    "PA": "EMD_EPD2D_PTE_R1Y_DPG",
    "IL": "EMD_EPD2D_PTE_R20_DPG", "IN": "EMD_EPD2D_PTE_R20_DPG",
    "MI": "EMD_EPD2D_PTE_R20_DPG", "OH": "EMD_EPD2D_PTE_R20_DPG",
    "WI": "EMD_EPD2D_PTE_R20_DPG",
    "IA": "EMD_EPD2D_PTE_R2X_DPG", "KS": "EMD_EPD2D_PTE_R2X_DPG",
    "MN": "EMD_EPD2D_PTE_R2X_DPG", "MO": "EMD_EPD2D_PTE_R2X_DPG",
    "NE": "EMD_EPD2D_PTE_R2X_DPG", "ND": "EMD_EPD2D_PTE_R2X_DPG",
    "SD": "EMD_EPD2D_PTE_R2X_DPG",
    "FL": "EMD_EPD2D_PTE_R30_DPG", "GA": "EMD_EPD2D_PTE_R30_DPG",
    "NC": "EMD_EPD2D_PTE_R30_DPG", "SC": "EMD_EPD2D_PTE_R30_DPG",
    "VA": "EMD_EPD2D_PTE_R30_DPG", "DC": "EMD_EPD2D_PTE_R30_DPG",
    "AL": "EMD_EPD2D_PTE_R3X_DPG", "AR": "EMD_EPD2D_PTE_R3X_DPG",
    "KY": "EMD_EPD2D_PTE_R3X_DPG", "LA": "EMD_EPD2D_PTE_R3X_DPG",
    "MS": "EMD_EPD2D_PTE_R3X_DPG", "TN": "EMD_EPD2D_PTE_R3X_DPG",
    "WV": "EMD_EPD2D_PTE_R3X_DPG",
    "CO": "EMD_EPD2D_PTE_R40_DPG", "ID": "EMD_EPD2D_PTE_R40_DPG",
    "MT": "EMD_EPD2D_PTE_R40_DPG", "UT": "EMD_EPD2D_PTE_R40_DPG",
    "WY": "EMD_EPD2D_PTE_R40_DPG",
    "AZ": "EMD_EPD2D_PTE_R4X_DPG", "NM": "EMD_EPD2D_PTE_R4X_DPG",
    "NV": "EMD_EPD2D_PTE_R4X_DPG", "OK": "EMD_EPD2D_PTE_R4X_DPG",
    "TX": "EMD_EPD2D_PTE_R4X_DPG",
    "AK": "EMD_EPD2D_PTE_R50_DPG", "CA": "EMD_EPD2D_PTE_R50_DPG",
    "HI": "EMD_EPD2D_PTE_R50_DPG", "OR": "EMD_EPD2D_PTE_R50_DPG",
    "WA": "EMD_EPD2D_PTE_R50_DPG"
]

actor EIAService {
    static let shared = EIAService()

    private var cachedPrice: EIAGasPrice?
    private var lastFetch: Date?
    private let cacheDuration: TimeInterval = 60 * 60 * 24  // refresh daily

    // National fallback price (updated manually if no API key is set)
    static let nationalFallback = 3.45

    func fetchGasPrice(state: String, apiKey: String?) async -> EIAGasPrice {
        // Return cached if still fresh
        if let cached = cachedPrice, let last = lastFetch, Date().timeIntervalSince(last) < cacheDuration {
            return cached
        }

        guard let key = apiKey, !key.isEmpty else {
            return EIAGasPrice(pricePerGallon: Self.nationalFallback, regionName: "National Average", weekOf: "Estimated", isLive: false)
        }

        let seriesId = stateToEIASeries[state] ?? "EMD_EPD2D_PTE_NUS_DPG"
        let urlStr = "https://api.eia.gov/v2/seriesid/\(seriesId)?api_key=\(key)&num=1"

        guard let url = URL(string: urlStr) else {
            return EIAGasPrice(pricePerGallon: Self.nationalFallback, regionName: "National Average", weekOf: "Estimated", isLive: false)
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let response = json["response"] as? [String: Any],
               let dataArr = response["data"] as? [[String: Any]],
               let first = dataArr.first,
               let value = first["value"] as? Double,
               let period = first["period"] as? String {
                let result = EIAGasPrice(pricePerGallon: value, regionName: "Regional Average", weekOf: period, isLive: true)
                cachedPrice = result
                lastFetch = Date()
                return result
            }
        } catch {}

        return EIAGasPrice(pricePerGallon: Self.nationalFallback, regionName: "National Average", weekOf: "Estimated", isLive: false)
    }
}
