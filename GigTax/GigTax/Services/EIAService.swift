import Foundation

// EIA (Energy Information Administration) — free weekly gas price data
// Sign up for a free key at: https://www.eia.gov/opendata/register.php
// Add your key in Settings → Backup & iCloud... no — Settings → Gas Price.
// Falls back to a per-state average table until a key is configured.

struct EIAGasPrice {
    let pricePerGallon: Double
    let regionName: String
    let weekOf: String
    let isLive: Bool
}

/// Per-state average regular-gasoline price, captured 2026-07-18 from AAA's
/// published state averages — a real fallback used until the driver sets up
/// a free EIA key for live daily data, and always used if they don't. Was
/// previously a single flat $3.45 "national fallback" for every driver in
/// every state regardless of real local prices (the actual bug a driver
/// found in the field — this table is the fix's core, not just a nicety).
/// Update periodically; these drift over time like any hardcoded price.
private let stateAverageGasPrice: [String: Double] = [
    "AL": 3.628, "AK": 4.666, "AZ": 4.217, "AR": 3.592, "CA": 5.459,
    "CO": 3.973, "CT": 4.072, "DE": 3.961, "DC": 4.110, "FL": 3.952,
    "GA": 3.766, "HI": 5.431, "ID": 4.049, "IL": 4.157, "IN": 3.368,
    "IA": 3.832, "KS": 3.671, "KY": 3.671, "LA": 3.575, "ME": 4.011,
    "MD": 3.989, "MA": 4.010, "MI": 4.158, "MN": 3.884, "MS": 3.555,
    "MO": 3.652, "MT": 4.093, "NE": 3.863, "NV": 4.591, "NH": 3.982,
    "NJ": 4.033, "NM": 4.001, "NY": 4.131, "NC": 3.680, "ND": 3.750,
    "OH": 3.900, "OK": 3.589, "OR": 4.546, "PA": 4.170, "RI": 4.022,
    "SC": 3.686, "SD": 3.896, "TN": 3.607, "TX": 3.567, "UT": 4.009,
    "VT": 4.099, "VA": 3.902, "WA": 5.003, "WV": 3.823, "WI": 3.783,
    "WY": 4.021,
]
private let nationalAverageGasPrice = 4.003  // simple mean of the table above, used only if the state code isn't recognized

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

    // Keyed by state so a cached price for one state is never accidentally
    // served for another (e.g. a driver who changes their profile's state).
    private var cachedPrices: [String: EIAGasPrice] = [:]
    private var lastFetchDates: [String: Date] = [:]
    private let cacheDuration: TimeInterval = 60 * 60 * 24  // refresh daily

    private func stateFallback(for state: String) -> EIAGasPrice {
        if let price = stateAverageGasPrice[state] {
            return EIAGasPrice(pricePerGallon: price, regionName: "\(state) Average (estimated)", weekOf: "Estimated", isLive: false)
        }
        return EIAGasPrice(pricePerGallon: nationalAverageGasPrice, regionName: "National Average (estimated)", weekOf: "Estimated", isLive: false)
    }

    func fetchGasPrice(state: String, apiKey: String?) async -> EIAGasPrice {
        // Return cached if still fresh
        if let cached = cachedPrices[state], let last = lastFetchDates[state], Date().timeIntervalSince(last) < cacheDuration {
            return cached
        }

        guard let key = apiKey, !key.isEmpty else {
            return stateFallback(for: state)
        }

        let seriesId = stateToEIASeries[state] ?? "EMD_EPD2D_PTE_NUS_DPG"
        let urlStr = "https://api.eia.gov/v2/seriesid/\(seriesId)?api_key=\(key)&num=1"

        guard let url = URL(string: urlStr) else {
            return stateFallback(for: state)
        }

        do {
            let (data, _) = try await NetworkRequest.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let response = json["response"] as? [String: Any],
               let dataArr = response["data"] as? [[String: Any]],
               let first = dataArr.first,
               let value = first["value"] as? Double,
               let period = first["period"] as? String {
                let result = EIAGasPrice(pricePerGallon: value, regionName: "Regional Average", weekOf: period, isLive: true)
                cachedPrices[state] = result
                lastFetchDates[state] = Date()
                return result
            }
        } catch {}

        return stateFallback(for: state)
    }
}
