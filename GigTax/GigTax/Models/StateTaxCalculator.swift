import Foundation

/// State income tax for all 50 states + DC, tax year 2025. Verified against
/// Tax Foundation's 2025 state rate dataset plus individual state DOR/
/// legislative sources where rates changed this year (many states cut rates
/// effective 2025 — this is a real annual-maintenance dataset, not a
/// one-time snapshot; several already have legislated further cuts for 2026
/// and beyond that will need picking up next filing season).
///
/// Filing-status note: where a state's published brackets don't distinguish
/// Head of Household from Single, HOH falls back to the Single schedule —
/// this matches how most of these states' own tax codes work (only
/// Single/MFJ get distinct schedules), it is not a guess unique to this app.
enum StateTaxCalculator {
    struct Bracket {
        let upTo: Double
        let rate: Double
    }

    private struct StateProfile {
        let hasNoTax: Bool
        let flatRate: Double?
        let singleBrackets: [Bracket]
        let jointBrackets: [Bracket]

        static let none = StateProfile(hasNoTax: true, flatRate: nil, singleBrackets: [], jointBrackets: [])

        static func flat(_ rate: Double) -> StateProfile {
            StateProfile(hasNoTax: false, flatRate: rate, singleBrackets: [], jointBrackets: [])
        }

        static func progressive(single: [Bracket], joint: [Bracket]? = nil) -> StateProfile {
            StateProfile(hasNoTax: false, flatRate: nil, singleBrackets: single, jointBrackets: joint ?? single)
        }
    }

    static func tax(onTaxableIncome income: Double, state: String, filingStatus: FilingStatus) -> Double {
        guard income > 0, let profile = profiles[state.uppercased()] else { return 0 }
        if profile.hasNoTax { return 0 }
        if let flatRate = profile.flatRate { return income * flatRate }
        let brackets = filingStatus == .marriedFilingJointly ? profile.jointBrackets : profile.singleBrackets
        return progressiveTax(income: income, brackets: brackets)
    }

    private static func progressiveTax(income: Double, brackets: [Bracket]) -> Double {
        guard income > 0 else { return 0 }
        var tax = 0.0
        var lowerBound = 0.0
        for bracket in brackets {
            let width = bracket.upTo - lowerBound
            let amountInBracket = min(max(income - lowerBound, 0), width)
            guard amountInBracket > 0 else { break }
            tax += amountInBracket * bracket.rate
            lowerBound = bracket.upTo
            if income <= lowerBound { break }
        }
        return tax
    }

    // MARK: - No income tax (9)

    private static let noTaxStates: [String: StateProfile] = [
        "AK": .none, "FL": .none, "NV": .none, "NH": .none, "SD": .none,
        "TN": .none, "TX": .none, "WA": .none, "WY": .none,
    ]

    // MARK: - Flat rate (12)

    private static let flatStates: [String: StateProfile] = [
        "AZ": .flat(0.0250),
        "CO": .flat(0.0440),
        "GA": .flat(0.0519),
        "IL": .flat(0.0495),
        "IN": .flat(0.0300),
        "IA": .flat(0.0380),
        "KY": .flat(0.0400),
        "LA": .flat(0.0300),
        "MI": .flat(0.0425),
        "NC": .flat(0.0425),
        "PA": .flat(0.0307),
        "UT": .flat(0.0450),
    ]

    // MARK: - Progressive brackets (30, incl. DC)

    private static let progressiveStates: [String: StateProfile] = [
        "AL": .progressive(
            single: [Bracket(upTo: 500, rate: 0.02), Bracket(upTo: 3_000, rate: 0.04), Bracket(upTo: .infinity, rate: 0.05)],
            joint: [Bracket(upTo: 1_000, rate: 0.02), Bracket(upTo: 6_000, rate: 0.04), Bracket(upTo: .infinity, rate: 0.05)]
        ),
        "AR": .progressive(single: [
            Bracket(upTo: 5_499, rate: 0.00), Bracket(upTo: 11_099, rate: 0.02), Bracket(upTo: 15_999, rate: 0.03),
            Bracket(upTo: 25_699, rate: 0.034), Bracket(upTo: .infinity, rate: 0.039),
        ]),
        "CA": .progressive(
            single: [
                Bracket(upTo: 10_756, rate: 0.01), Bracket(upTo: 25_499, rate: 0.02), Bracket(upTo: 40_245, rate: 0.04),
                Bracket(upTo: 55_866, rate: 0.06), Bracket(upTo: 70_606, rate: 0.08), Bracket(upTo: 360_659, rate: 0.093),
                Bracket(upTo: 432_787, rate: 0.103), Bracket(upTo: 721_314, rate: 0.113), Bracket(upTo: .infinity, rate: 0.133),
            ],
            joint: [
                Bracket(upTo: 21_512, rate: 0.01), Bracket(upTo: 50_998, rate: 0.02), Bracket(upTo: 80_490, rate: 0.04),
                Bracket(upTo: 111_732, rate: 0.06), Bracket(upTo: 141_732, rate: 0.08), Bracket(upTo: 721_318, rate: 0.093),
                Bracket(upTo: 865_574, rate: 0.103), Bracket(upTo: 1_000_000, rate: 0.113), Bracket(upTo: .infinity, rate: 0.133),
            ]
        ),
        "CT": .progressive(
            single: [
                Bracket(upTo: 10_000, rate: 0.02), Bracket(upTo: 50_000, rate: 0.045), Bracket(upTo: 100_000, rate: 0.055),
                Bracket(upTo: 200_000, rate: 0.06), Bracket(upTo: 250_000, rate: 0.065), Bracket(upTo: 500_000, rate: 0.069),
                Bracket(upTo: .infinity, rate: 0.0699),
            ],
            joint: [
                Bracket(upTo: 20_000, rate: 0.02), Bracket(upTo: 100_000, rate: 0.045), Bracket(upTo: 200_000, rate: 0.055),
                Bracket(upTo: 400_000, rate: 0.06), Bracket(upTo: 500_000, rate: 0.065), Bracket(upTo: 1_000_000, rate: 0.069),
                Bracket(upTo: .infinity, rate: 0.0699),
            ]
        ),
        "DE": .progressive(single: [
            Bracket(upTo: 2_000, rate: 0.00), Bracket(upTo: 5_000, rate: 0.022), Bracket(upTo: 10_000, rate: 0.039),
            Bracket(upTo: 20_000, rate: 0.048), Bracket(upTo: 25_000, rate: 0.052), Bracket(upTo: 60_000, rate: 0.0555),
            Bracket(upTo: .infinity, rate: 0.066),
        ]),
        "DC": .progressive(single: [
            Bracket(upTo: 10_000, rate: 0.04), Bracket(upTo: 40_000, rate: 0.06), Bracket(upTo: 60_000, rate: 0.065),
            Bracket(upTo: 250_000, rate: 0.085), Bracket(upTo: 500_000, rate: 0.0925), Bracket(upTo: 1_000_000, rate: 0.0975),
            Bracket(upTo: .infinity, rate: 0.1075),
        ]),
        "HI": .progressive(
            single: [
                Bracket(upTo: 9_600, rate: 0.014), Bracket(upTo: 14_400, rate: 0.032), Bracket(upTo: 19_200, rate: 0.055),
                Bracket(upTo: 24_000, rate: 0.064), Bracket(upTo: 36_000, rate: 0.068), Bracket(upTo: 48_000, rate: 0.072),
                Bracket(upTo: 125_000, rate: 0.076), Bracket(upTo: 175_000, rate: 0.079), Bracket(upTo: 225_000, rate: 0.0825),
                Bracket(upTo: 275_000, rate: 0.09), Bracket(upTo: 325_000, rate: 0.10), Bracket(upTo: .infinity, rate: 0.11),
            ],
            joint: [
                Bracket(upTo: 19_200, rate: 0.014), Bracket(upTo: 28_800, rate: 0.032), Bracket(upTo: 38_400, rate: 0.055),
                Bracket(upTo: 48_000, rate: 0.064), Bracket(upTo: 72_000, rate: 0.068), Bracket(upTo: 96_000, rate: 0.072),
                Bracket(upTo: 250_000, rate: 0.076), Bracket(upTo: 350_000, rate: 0.079), Bracket(upTo: 450_000, rate: 0.0825),
                Bracket(upTo: 550_000, rate: 0.09), Bracket(upTo: 650_000, rate: 0.10), Bracket(upTo: .infinity, rate: 0.11),
            ]
        ),
        // Idaho and Mississippi are flat-above-a-zero-floor — modeled as 2-bracket
        // progressive rather than pure flat, since the first slice is untaxed.
        "ID": .progressive(
            single: [Bracket(upTo: 4_811, rate: 0.00), Bracket(upTo: .infinity, rate: 0.053)],
            joint: [Bracket(upTo: 9_622, rate: 0.00), Bracket(upTo: .infinity, rate: 0.053)]
        ),
        "MS": .progressive(single: [Bracket(upTo: 10_000, rate: 0.00), Bracket(upTo: .infinity, rate: 0.044)]),
        "KS": .progressive(
            single: [Bracket(upTo: 23_000, rate: 0.052), Bracket(upTo: .infinity, rate: 0.0558)],
            joint: [Bracket(upTo: 46_000, rate: 0.052), Bracket(upTo: .infinity, rate: 0.0558)]
        ),
        "ME": .progressive(
            single: [Bracket(upTo: 26_800, rate: 0.058), Bracket(upTo: 63_450, rate: 0.0675), Bracket(upTo: .infinity, rate: 0.0715)],
            joint: [Bracket(upTo: 53_600, rate: 0.058), Bracket(upTo: 126_900, rate: 0.0675), Bracket(upTo: .infinity, rate: 0.0715)]
        ),
        // Maryland STATE bracket only — county "piggyback" tax is separate, see MarylandCountyTax.swift.
        "MD": .progressive(
            single: [
                Bracket(upTo: 1_000, rate: 0.02), Bracket(upTo: 2_000, rate: 0.03), Bracket(upTo: 3_000, rate: 0.04),
                Bracket(upTo: 100_000, rate: 0.0475), Bracket(upTo: 125_000, rate: 0.05), Bracket(upTo: 150_000, rate: 0.0525),
                Bracket(upTo: 250_000, rate: 0.055), Bracket(upTo: .infinity, rate: 0.0575),
            ],
            joint: [
                Bracket(upTo: 1_000, rate: 0.02), Bracket(upTo: 2_000, rate: 0.03), Bracket(upTo: 3_000, rate: 0.04),
                Bracket(upTo: 150_000, rate: 0.0475), Bracket(upTo: 175_000, rate: 0.05), Bracket(upTo: 225_000, rate: 0.0525),
                Bracket(upTo: 300_000, rate: 0.055), Bracket(upTo: .infinity, rate: 0.0575),
            ]
        ),
        // 5% flat + 4% "millionaires" surtax above the (inflation-indexed) threshold —
        // modeled as 2 brackets, mathematically identical to flat-plus-surtax.
        "MA": .progressive(single: [Bracket(upTo: 1_083_150, rate: 0.05), Bracket(upTo: .infinity, rate: 0.09)]),
        "MN": .progressive(
            single: [
                Bracket(upTo: 32_570, rate: 0.0535), Bracket(upTo: 106_990, rate: 0.068),
                Bracket(upTo: 198_630, rate: 0.0785), Bracket(upTo: .infinity, rate: 0.0985),
            ],
            joint: [
                Bracket(upTo: 47_620, rate: 0.0535), Bracket(upTo: 189_180, rate: 0.068),
                Bracket(upTo: 330_410, rate: 0.0785), Bracket(upTo: .infinity, rate: 0.0985),
            ]
        ),
        "MO": .progressive(single: [
            Bracket(upTo: 1_313, rate: 0.00), Bracket(upTo: 2_626, rate: 0.02), Bracket(upTo: 3_939, rate: 0.025),
            Bracket(upTo: 5_252, rate: 0.03), Bracket(upTo: 6_565, rate: 0.035), Bracket(upTo: 7_878, rate: 0.04),
            Bracket(upTo: 9_191, rate: 0.045), Bracket(upTo: .infinity, rate: 0.047),
        ]),
        "MT": .progressive(
            single: [Bracket(upTo: 21_100, rate: 0.047), Bracket(upTo: .infinity, rate: 0.059)],
            joint: [Bracket(upTo: 42_200, rate: 0.047), Bracket(upTo: .infinity, rate: 0.059)]
        ),
        "NE": .progressive(
            single: [
                Bracket(upTo: 4_030, rate: 0.0246), Bracket(upTo: 24_120, rate: 0.0351),
                Bracket(upTo: 38_870, rate: 0.0501), Bracket(upTo: .infinity, rate: 0.052),
            ],
            joint: [
                Bracket(upTo: 8_040, rate: 0.0246), Bracket(upTo: 48_250, rate: 0.0351),
                Bracket(upTo: 77_730, rate: 0.0501), Bracket(upTo: .infinity, rate: 0.052),
            ]
        ),
        "NJ": .progressive(
            single: [
                Bracket(upTo: 20_000, rate: 0.014), Bracket(upTo: 35_000, rate: 0.0175), Bracket(upTo: 40_000, rate: 0.035),
                Bracket(upTo: 75_000, rate: 0.05525), Bracket(upTo: 500_000, rate: 0.0637), Bracket(upTo: 1_000_000, rate: 0.0897),
                Bracket(upTo: .infinity, rate: 0.1075),
            ],
            joint: [
                Bracket(upTo: 20_000, rate: 0.014), Bracket(upTo: 50_000, rate: 0.0175), Bracket(upTo: 70_000, rate: 0.0245),
                Bracket(upTo: 80_000, rate: 0.035), Bracket(upTo: 150_000, rate: 0.05525), Bracket(upTo: 500_000, rate: 0.0637),
                Bracket(upTo: 1_000_000, rate: 0.0897), Bracket(upTo: .infinity, rate: 0.1075),
            ]
        ),
        "NM": .progressive(
            single: [
                Bracket(upTo: 5_500, rate: 0.015), Bracket(upTo: 16_500, rate: 0.032), Bracket(upTo: 33_500, rate: 0.043),
                Bracket(upTo: 66_500, rate: 0.047), Bracket(upTo: 210_000, rate: 0.049), Bracket(upTo: .infinity, rate: 0.059),
            ],
            joint: [
                Bracket(upTo: 8_000, rate: 0.015), Bracket(upTo: 25_000, rate: 0.032), Bracket(upTo: 50_000, rate: 0.043),
                Bracket(upTo: 100_000, rate: 0.047), Bracket(upTo: 315_000, rate: 0.049), Bracket(upTo: .infinity, rate: 0.059),
            ]
        ),
        "NY": .progressive(
            single: [
                Bracket(upTo: 8_500, rate: 0.04), Bracket(upTo: 11_700, rate: 0.045), Bracket(upTo: 13_900, rate: 0.0525),
                Bracket(upTo: 80_650, rate: 0.055), Bracket(upTo: 215_400, rate: 0.06), Bracket(upTo: 1_077_550, rate: 0.0685),
                Bracket(upTo: 5_000_000, rate: 0.0965), Bracket(upTo: 25_000_000, rate: 0.103), Bracket(upTo: .infinity, rate: 0.109),
            ],
            joint: [
                Bracket(upTo: 17_150, rate: 0.04), Bracket(upTo: 23_600, rate: 0.045), Bracket(upTo: 27_900, rate: 0.0525),
                Bracket(upTo: 161_550, rate: 0.055), Bracket(upTo: 323_200, rate: 0.06), Bracket(upTo: 2_155_350, rate: 0.0685),
                Bracket(upTo: 5_000_000, rate: 0.0965), Bracket(upTo: 25_000_000, rate: 0.103), Bracket(upTo: .infinity, rate: 0.109),
            ]
        ),
        "ND": .progressive(
            single: [Bracket(upTo: 48_475, rate: 0.00), Bracket(upTo: 244_825, rate: 0.0195), Bracket(upTo: .infinity, rate: 0.025)],
            joint: [Bracket(upTo: 80_975, rate: 0.00), Bracket(upTo: 298_075, rate: 0.0195), Bracket(upTo: .infinity, rate: 0.025)]
        ),
        "OH": .progressive(single: [
            Bracket(upTo: 26_050, rate: 0.00), Bracket(upTo: 100_000, rate: 0.0275), Bracket(upTo: .infinity, rate: 0.03125),
        ]),
        "OK": .progressive(
            single: [
                Bracket(upTo: 1_000, rate: 0.0025), Bracket(upTo: 2_500, rate: 0.0075), Bracket(upTo: 3_750, rate: 0.0175),
                Bracket(upTo: 4_900, rate: 0.0275), Bracket(upTo: 7_200, rate: 0.0375), Bracket(upTo: .infinity, rate: 0.0475),
            ],
            joint: [
                Bracket(upTo: 2_000, rate: 0.0025), Bracket(upTo: 5_000, rate: 0.0075), Bracket(upTo: 7_500, rate: 0.0175),
                Bracket(upTo: 9_800, rate: 0.0275), Bracket(upTo: 14_400, rate: 0.0375), Bracket(upTo: .infinity, rate: 0.0475),
            ]
        ),
        "OR": .progressive(
            single: [
                Bracket(upTo: 4_400, rate: 0.0475), Bracket(upTo: 11_050, rate: 0.0675),
                Bracket(upTo: 125_000, rate: 0.0875), Bracket(upTo: .infinity, rate: 0.099),
            ],
            joint: [
                Bracket(upTo: 8_800, rate: 0.0475), Bracket(upTo: 22_100, rate: 0.0675),
                Bracket(upTo: 250_000, rate: 0.0875), Bracket(upTo: .infinity, rate: 0.099),
            ]
        ),
        "RI": .progressive(single: [
            Bracket(upTo: 79_900, rate: 0.0375), Bracket(upTo: 181_650, rate: 0.0475), Bracket(upTo: .infinity, rate: 0.0599),
        ]),
        "SC": .progressive(single: [
            Bracket(upTo: 3_560, rate: 0.00), Bracket(upTo: 17_830, rate: 0.03), Bracket(upTo: .infinity, rate: 0.06),
        ]),
        "VT": .progressive(
            single: [
                Bracket(upTo: 47_900, rate: 0.0335), Bracket(upTo: 116_000, rate: 0.066),
                Bracket(upTo: 242_000, rate: 0.076), Bracket(upTo: .infinity, rate: 0.0875),
            ],
            joint: [
                Bracket(upTo: 79_950, rate: 0.0335), Bracket(upTo: 193_300, rate: 0.066),
                Bracket(upTo: 294_600, rate: 0.076), Bracket(upTo: .infinity, rate: 0.0875),
            ]
        ),
        "VA": .progressive(single: [
            Bracket(upTo: 3_000, rate: 0.02), Bracket(upTo: 5_000, rate: 0.03), Bracket(upTo: 17_000, rate: 0.05),
            Bracket(upTo: .infinity, rate: 0.0575),
        ]),
        "WV": .progressive(single: [
            Bracket(upTo: 10_000, rate: 0.0222), Bracket(upTo: 25_000, rate: 0.0296), Bracket(upTo: 40_000, rate: 0.0333),
            Bracket(upTo: 60_000, rate: 0.0444), Bracket(upTo: .infinity, rate: 0.0482),
        ]),
        "WI": .progressive(
            single: [
                Bracket(upTo: 14_680, rate: 0.035), Bracket(upTo: 29_370, rate: 0.044),
                Bracket(upTo: 323_290, rate: 0.053), Bracket(upTo: .infinity, rate: 0.0765),
            ],
            joint: [
                Bracket(upTo: 19_580, rate: 0.035), Bracket(upTo: 39_150, rate: 0.044),
                Bracket(upTo: 431_060, rate: 0.053), Bracket(upTo: .infinity, rate: 0.0765),
            ]
        ),
    ]

    private static let profiles: [String: StateProfile] = noTaxStates
        .merging(flatStates) { _, new in new }
        .merging(progressiveStates) { _, new in new }

    /// Single entry point combining state bracket tax with Maryland's county
    /// piggyback tax where applicable — this is what a caller (e.g. a future
    /// tax summary screen) passes as `TaxEngine.summary`'s `stateTax` closure.
    static func totalStateAndLocalTax(onTaxableIncome income: Double, state: String, county: String, filingStatus: FilingStatus) -> Double {
        let stateTax = tax(onTaxableIncome: income, state: state, filingStatus: filingStatus)
        let countyTax = state.uppercased() == "MD"
            ? MarylandCountyTax.tax(onMarylandTaxableIncome: income, county: county, filingStatus: filingStatus)
            : 0
        return stateTax + countyTax
    }
}
