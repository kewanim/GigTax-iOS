import SwiftUI

struct ProfileSetupView: View {
    @Bindable var data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Step 3 of 4").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                        Text("Tax Profile").font(.title2).fontWeight(.bold)
                        Text("Used to calculate your federal, state, and self-employment taxes accurately.")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .listRowInsets(.init())
                .listRowBackground(Color.clear)

                Section("Filing Status") {
                    Picker("Filing Status", selection: $data.filingStatus) {
                        ForEach(FilingStatus.allCases, id: \.self) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text("Standard deduction: \(data.filingStatus.standardDeduction, format: .currency(code: "USD").precision(.fractionLength(0)))")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Section("Location") {
                    Picker("State", selection: $data.state) {
                        ForEach(USStates.all, id: \.code) { state in
                            Text(state.name).tag(state.code)
                        }
                    }

                    if data.state == "MD" {
                        Picker("County", selection: $data.county) {
                            ForEach(MDCounties.all, id: \.self) { Text($0).tag($0) }
                        }
                        Text("Maryland has a county income tax in addition to state tax.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Section("Income Goals (Optional)") {
                    LabeledContent("Weekly Goal") {
                        HStack {
                            Text("$").foregroundStyle(.secondary)
                            TextField("e.g. 1000", text: $data.weeklyGoal)
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                    }
                    LabeledContent("Monthly Goal") {
                        HStack {
                            Text("$").foregroundStyle(.secondary)
                            TextField("e.g. 4000", text: $data.monthlyGoal)
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                    }
                    Text("Track progress toward your earnings targets on the dashboard.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Back", action: onBack) }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Next", action: onNext).fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Static data

enum USStates {
    struct State { let code: String; let name: String }
    static let all: [State] = [
        .init(code: "AL", name: "Alabama"), .init(code: "AK", name: "Alaska"),
        .init(code: "AZ", name: "Arizona"), .init(code: "AR", name: "Arkansas"),
        .init(code: "CA", name: "California"), .init(code: "CO", name: "Colorado"),
        .init(code: "CT", name: "Connecticut"), .init(code: "DE", name: "Delaware"),
        .init(code: "DC", name: "District of Columbia"), .init(code: "FL", name: "Florida"),
        .init(code: "GA", name: "Georgia"), .init(code: "HI", name: "Hawaii"),
        .init(code: "ID", name: "Idaho"), .init(code: "IL", name: "Illinois"),
        .init(code: "IN", name: "Indiana"), .init(code: "IA", name: "Iowa"),
        .init(code: "KS", name: "Kansas"), .init(code: "KY", name: "Kentucky"),
        .init(code: "LA", name: "Louisiana"), .init(code: "ME", name: "Maine"),
        .init(code: "MD", name: "Maryland"), .init(code: "MA", name: "Massachusetts"),
        .init(code: "MI", name: "Michigan"), .init(code: "MN", name: "Minnesota"),
        .init(code: "MS", name: "Mississippi"), .init(code: "MO", name: "Missouri"),
        .init(code: "MT", name: "Montana"), .init(code: "NE", name: "Nebraska"),
        .init(code: "NV", name: "Nevada"), .init(code: "NH", name: "New Hampshire"),
        .init(code: "NJ", name: "New Jersey"), .init(code: "NM", name: "New Mexico"),
        .init(code: "NY", name: "New York"), .init(code: "NC", name: "North Carolina"),
        .init(code: "ND", name: "North Dakota"), .init(code: "OH", name: "Ohio"),
        .init(code: "OK", name: "Oklahoma"), .init(code: "OR", name: "Oregon"),
        .init(code: "PA", name: "Pennsylvania"), .init(code: "RI", name: "Rhode Island"),
        .init(code: "SC", name: "South Carolina"), .init(code: "SD", name: "South Dakota"),
        .init(code: "TN", name: "Tennessee"), .init(code: "TX", name: "Texas"),
        .init(code: "UT", name: "Utah"), .init(code: "VT", name: "Vermont"),
        .init(code: "VA", name: "Virginia"), .init(code: "WA", name: "Washington"),
        .init(code: "WV", name: "West Virginia"), .init(code: "WI", name: "Wisconsin"),
        .init(code: "WY", name: "Wyoming"),
    ]
}

enum MDCounties {
    static let all = [
        "Allegany", "Anne Arundel", "Baltimore City", "Baltimore County",
        "Calvert", "Caroline", "Carroll", "Cecil", "Charles", "Dorchester",
        "Frederick", "Garrett", "Harford", "Howard", "Kent", "Montgomery",
        "Prince George's", "Queen Anne's", "Somerset", "St. Mary's",
        "Talbot", "Washington", "Wicomico", "Worcester",
    ]
}

#Preview {
    ProfileSetupView(data: OnboardingData(), onNext: {}, onBack: {})
}
