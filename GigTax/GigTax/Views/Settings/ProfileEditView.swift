import SwiftUI
import SwiftData

struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    let driverProfile: DriverProfile

    @State private var driverName: String
    @State private var filingStatus: FilingStatus
    @State private var state: String
    @State private var county: String
    @State private var weeklyGoalText: String
    @State private var monthlyGoalText: String
    @State private var phoneBusinessPercentText: String
    @State private var phoneMonthlyBillText: String
    @State private var cleaningMonthlyText: String
    @State private var maintenanceMonthlyText: String
    @State private var phoneYearlyText: String
    @State private var taxSavingsPercentText: String
    @State private var preferredDeductionMethod: DeductionMethod

    init(driverProfile: DriverProfile) {
        self.driverProfile = driverProfile
        _driverName = State(initialValue: driverProfile.driverName ?? "")
        _filingStatus = State(initialValue: driverProfile.filingStatus)
        _state = State(initialValue: driverProfile.state)
        _county = State(initialValue: driverProfile.county)
        _weeklyGoalText = State(initialValue: driverProfile.weeklyGoal.map { String($0) } ?? "")
        _monthlyGoalText = State(initialValue: driverProfile.monthlyGoal.map { String($0) } ?? "")
        _phoneBusinessPercentText = State(initialValue: String(driverProfile.phoneBusinessPercent))
        _phoneMonthlyBillText = State(initialValue: String(driverProfile.phoneMonthlyBill))
        _cleaningMonthlyText = State(initialValue: String(driverProfile.cleaningMonthly))
        _maintenanceMonthlyText = State(initialValue: String(driverProfile.maintenanceMonthly))
        _phoneYearlyText = State(initialValue: String(driverProfile.phoneYearly))
        _taxSavingsPercentText = State(initialValue: String(driverProfile.taxSavingsPercent))
        _preferredDeductionMethod = State(initialValue: driverProfile.preferredDeductionMethod)
    }

    var body: some View {
        Form {
            Section("Filing Status") {
                Picker("Filing Status", selection: $filingStatus) {
                    ForEach(FilingStatus.allCases, id: \.self) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                Text("Standard deduction: \(filingStatus.standardDeduction, format: .currency(code: "USD").precision(.fractionLength(0)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Location") {
                Picker("State", selection: $state) {
                    ForEach(USStates.all, id: \.code) { s in
                        Text(s.name).tag(s.code)
                    }
                }
                if state == "MD" {
                    Picker("County", selection: $county) {
                        ForEach(MDCounties.all, id: \.self) { Text($0).tag($0) }
                    }
                }
            }

            Section("Income Goals (Optional)") {
                LabeledContent("Weekly Goal") {
                    TextField("e.g. 1000", text: $weeklyGoalText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Monthly Goal") {
                    TextField("e.g. 4000", text: $monthlyGoalText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section("Deductions") {
                Picker("Preferred Method", selection: $preferredDeductionMethod) {
                    Text("Standard Mileage").tag(DeductionMethod.standard)
                    Text("Actual Expense").tag(DeductionMethod.actual)
                }
                LabeledContent("Phone Business Use %") {
                    TextField("0-100", text: $phoneBusinessPercentText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Phone Monthly Bill") {
                    TextField("$", text: $phoneMonthlyBillText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Car Cleaning (Monthly)") {
                    TextField("$", text: $cleaningMonthlyText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Maintenance (Monthly)") {
                    TextField("$", text: $maintenanceMonthlyText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Phone Purchase (Yearly)") {
                    TextField("$", text: $phoneYearlyText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }

            Section {
                LabeledContent("Tax Savings Set-Aside %") {
                    TextField("0-100", text: $taxSavingsPercentText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            } footer: {
                Text("Suggested percentage of each week's earnings to set aside for taxes.")
            }

            Section("Your Name") {
                TextField("Full Name", text: $driverName)
                    .autocorrectionDisabled()
            }
        }
        .navigationTitle("Edit Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") { save() }
                    .fontWeight(.semibold)
            }
        }
    }

    private func save() {
        driverProfile.driverName = driverName.isEmpty ? nil : driverName
        driverProfile.filingStatus = filingStatus
        driverProfile.state = state
        driverProfile.county = county
        driverProfile.weeklyGoal = Double(weeklyGoalText)
        driverProfile.monthlyGoal = Double(monthlyGoalText)
        driverProfile.phoneBusinessPercent = Double(phoneBusinessPercentText) ?? driverProfile.phoneBusinessPercent
        driverProfile.phoneMonthlyBill = Double(phoneMonthlyBillText) ?? driverProfile.phoneMonthlyBill
        driverProfile.cleaningMonthly = Double(cleaningMonthlyText) ?? driverProfile.cleaningMonthly
        driverProfile.maintenanceMonthly = Double(maintenanceMonthlyText) ?? driverProfile.maintenanceMonthly
        driverProfile.phoneYearly = Double(phoneYearlyText) ?? driverProfile.phoneYearly
        driverProfile.taxSavingsPercent = Double(taxSavingsPercentText) ?? driverProfile.taxSavingsPercent
        driverProfile.preferredDeductionMethod = preferredDeductionMethod
        // No explicit tax-recalc call needed — every screen that shows tax
        // numbers (Dashboard, Quarterly Payments, Schedule C, Optimizer)
        // reads DriverProfile live via @Query, so the next time any of them
        // appears it recomputes from these updated values automatically.
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ProfileEditView(driverProfile: DriverProfile())
    }
}
