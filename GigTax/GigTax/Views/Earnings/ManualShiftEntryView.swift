import SwiftUI
import SwiftData

struct ManualShiftEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var date = Date()
    @State private var platform = Platform.uber
    @State private var grossIncomeText = ""
    @State private var tipsText = ""
    @State private var bonusesText = ""
    @State private var hoursWorkedText = ""
    @State private var notes = ""

    private var grossIncome: Double { Double(grossIncomeText) ?? 0 }
    private var tips: Double { Double(tipsText) ?? 0 }
    private var bonuses: Double { Double(bonusesText) ?? 0 }
    private var hoursWorked: Double { Double(hoursWorkedText) ?? 0 }
    private var canSave: Bool { grossIncome > 0 || tips > 0 || bonuses > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("When") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Platform", selection: $platform) {
                        ForEach(Platform.allCases, id: \.self) { p in
                            Label(p.rawValue, systemImage: p.icon).tag(p)
                        }
                    }
                }

                Section("Earnings") {
                    LabeledContent("Gross Income") {
                        TextField("0.00", text: $grossIncomeText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("grossIncomeField")
                    }
                    LabeledContent("Tips") {
                        TextField("0.00", text: $tipsText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("tipsField")
                    }
                    LabeledContent("Bonuses") {
                        TextField("0.00", text: $bonusesText)
                            .accessibilityIdentifier("bonusesField")
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Time") {
                    LabeledContent("Hours Worked") {
                        TextField("Optional", text: $hoursWorkedText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("Log Shift")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
        }
    }

    private func save() {
        let shift = Shift(
            date: date,
            platform: platform,
            grossIncome: grossIncome,
            tips: tips,
            bonuses: bonuses,
            hoursWorked: hoursWorked,
            notes: notes,
            importSource: "manual"
        )
        modelContext.insert(shift)
        dismiss()
    }
}

#Preview {
    ManualShiftEntryView()
        .modelContainer(for: Shift.self, inMemory: true)
}
