import SwiftUI
import SwiftData

struct ManualShiftEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// When editing an existing shift (e.g. adding late tips), changes are
    /// written back to it instead of creating a new Shift.
    private let editingShift: Shift?

    @State private var date: Date
    @State private var platform: Platform
    @State private var grossIncomeText: String
    @State private var tipsText: String
    @State private var bonusesText: String
    @State private var hoursWorkedText: String
    @State private var notes: String

    init(editing shift: Shift? = nil, defaultPlatform: Platform? = nil) {
        editingShift = shift
        _date = State(initialValue: shift?.date ?? Date())
        _platform = State(initialValue: shift?.platform ?? defaultPlatform ?? .uber)
        _grossIncomeText = State(initialValue: shift.map { $0.grossIncome == 0 ? "" : String($0.grossIncome) } ?? "")
        _tipsText = State(initialValue: shift.map { $0.tips == 0 ? "" : String($0.tips) } ?? "")
        _bonusesText = State(initialValue: shift.map { $0.bonuses == 0 ? "" : String($0.bonuses) } ?? "")
        _hoursWorkedText = State(initialValue: shift.map { $0.hoursWorked == 0 ? "" : String($0.hoursWorked) } ?? "")
        _notes = State(initialValue: shift?.notes ?? "")
    }

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
            .navigationTitle(editingShift == nil ? "Log Shift" : "Edit Shift")
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
        if let existing = editingShift {
            existing.date = date
            existing.platform = platform
            existing.grossIncome = grossIncome
            existing.tips = tips
            existing.bonuses = bonuses
            existing.hoursWorked = hoursWorked
            existing.notes = notes
            existing.lastModified = .now
        } else {
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
        }
        LastUsedPlatformStore.record(platform)
        dismiss()
    }
}

#Preview {
    ManualShiftEntryView()
        .modelContainer(for: Shift.self, inMemory: true)
}
