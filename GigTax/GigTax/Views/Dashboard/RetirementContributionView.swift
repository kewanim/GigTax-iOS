import SwiftUI
import SwiftData

struct RetirementContributionView: View {
    @Query private var shifts: [Shift]
    @Query private var trips: [Trip]
    @Query private var expenses: [Expense]
    @Query private var driverProfiles: [DriverProfile]
    @Query private var vehicles: [Vehicle]
    @Query private var recurringExpenses: [RecurringExpense]

    let taxYear: Int

    @State private var ageBracket = RetirementContributionCalculator.AgeBracket.under50

    private var driverProfile: DriverProfile? { driverProfiles.first }

    private var netProfit: Double {
        TaxYearSummaryBuilder.build(
            shifts: shifts, trips: trips, expenses: expenses, driverProfile: driverProfile, taxYear: taxYear, vehicle: vehicles.first, recurringExpenses: recurringExpenses
        ).netProfit
    }

    private var result: RetirementContributionCalculator.Result {
        RetirementContributionCalculator.calculate(netProfit: netProfit, taxYear: taxYear, ageBracket: ageBracket)
    }

    private var marginalRate: Double {
        TaxYearSummaryBuilder.build(
            shifts: shifts, trips: trips, expenses: expenses, driverProfile: driverProfile, taxYear: taxYear, vehicle: vehicles.first, recurringExpenses: recurringExpenses
        ).marginalRate
    }

    var body: some View {
        List {
            explainerSection
            Section {
                Picker("Age", selection: $ageBracket) {
                    ForEach(RetirementContributionCalculator.AgeBracket.allCases, id: \.self) { bracket in
                        Text(bracket.rawValue).tag(bracket)
                    }
                }
            } footer: {
                Text("Affects how much extra you can defer into a Solo 401(k) via catch-up contributions.")
            }

            Section {
                LabeledContent("Net Profit (\(String(taxYear)))") {
                    Text(netProfit, format: .currency(code: "USD"))
                }
                LabeledContent("Net Earnings from Self-Employment") {
                    Text(result.netEarningsFromSelfEmployment, format: .currency(code: "USD"))
                }
            } footer: {
                Text("Net earnings = net profit minus the deduction for half of your self-employment tax — this is the base retirement contributions are calculated from, not raw net profit.")
            }

            Section {
                LabeledContent("Max SEP-IRA Contribution") {
                    Text(result.sepContribution, format: .currency(code: "USD"))
                        .fontWeight(.semibold)
                }
                LabeledContent("Tax Savings") {
                    Text(result.sepContribution * marginalRate, format: .currency(code: "USD"))
                        .foregroundStyle(.green)
                }
            } header: {
                Text("SEP-IRA")
            } footer: {
                Text("20% of net earnings from self-employment (the self-employed reduced rate — not the 25% a W-2 employer could give an employee), capped at \(Int(RetirementContributionCalculator.overallLimit(taxYear: taxYear)).formatted()).")
            }

            Section {
                LabeledContent("Elective Deferral") {
                    Text(result.solo401kElectiveDeferral, format: .currency(code: "USD"))
                }
                LabeledContent("Employer Contribution") {
                    Text(result.solo401kEmployerContribution, format: .currency(code: "USD"))
                }
                LabeledContent("Total Solo 401(k) Contribution") {
                    Text(result.solo401kTotalContribution, format: .currency(code: "USD"))
                        .fontWeight(.semibold)
                }
                LabeledContent("Tax Savings") {
                    Text(result.solo401kTotalContribution * marginalRate, format: .currency(code: "USD"))
                        .foregroundStyle(.green)
                }
            } header: {
                Text("Solo 401(k)")
            } footer: {
                Text("A flat elective deferral (up to \(Int(RetirementContributionCalculator.electiveDeferralLimit(taxYear: taxYear, ageBracket: ageBracket)).formatted()) at your age) plus the same 20% employer contribution as a SEP-IRA — usually beats a SEP-IRA for low-to-mid earners since the deferral stacks on top.")
            }
        }
        .navigationTitle("Retirement Contributions")
    }

    private var explainerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                Text("Retirement Accounts for the Self-Employed").font(.headline)
                Text("As a self-employed driver, you can shelter a real chunk of this year's income from tax by contributing to a SEP-IRA or Solo 401(k) — money you set aside now, invest, and pay tax on later in retirement (usually at a lower rate).")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("A SEP-IRA is simpler to set up. A Solo 401(k) usually lets you contribute more at the same income, because it adds a flat employee deferral on top of the same employer percentage.")
                    .font(.subheadline).foregroundStyle(.secondary)
                Label("These figures assume you have no other retirement plan or W-2 job this year. Opening and funding an account has real deadlines and paperwork — this is a planning estimate, not a substitute for a tax preparer or plan provider.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            .padding(.vertical, 4)
        }
    }
}

#Preview {
    NavigationStack {
        RetirementContributionView(taxYear: Calendar.current.component(.year, from: .now))
    }
    .modelContainer(for: [Shift.self, Trip.self, Expense.self, DriverProfile.self, Vehicle.self], inMemory: true)
}
