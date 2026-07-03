import SwiftUI
import SwiftData

struct ManualExpenseEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let editingExpense: Expense?

    @State private var date: Date
    @State private var category: ExpenseCategory
    @State private var amountText: String
    @State private var notes: String
    @State private var receiptPath: String?

    init(editing expense: Expense? = nil) {
        editingExpense = expense
        _date = State(initialValue: expense?.date ?? Date())
        _category = State(initialValue: expense?.category ?? .fuel)
        _amountText = State(initialValue: expense.map { $0.amount == 0 ? "" : String($0.amount) } ?? "")
        _notes = State(initialValue: expense?.notes ?? "")
        _receiptPath = State(initialValue: expense?.receiptImagePath)
    }

    private var amount: Double { Double(amountText) ?? 0 }
    private var canSave: Bool { amount > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { c in
                            Label(c.rawValue, systemImage: c.icon).tag(c)
                        }
                    }
                    LabeledContent("Amount") {
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("expenseAmountField")
                    }
                }

                Section("Notes") {
                    TextField("Optional", text: $notes, axis: .vertical)
                }

                ReceiptPickerView(receiptPath: $receiptPath)
            }
            .navigationTitle(editingExpense == nil ? "Log Expense" : "Edit Expense")
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
        if let existing = editingExpense {
            existing.date = date
            existing.category = category
            existing.amount = amount
            existing.notes = notes
            existing.receiptImagePath = receiptPath
        } else {
            let expense = Expense(date: date, category: category, amount: amount, notes: notes)
            expense.receiptImagePath = receiptPath
            modelContext.insert(expense)
        }
        dismiss()
    }
}

#Preview {
    ManualExpenseEntryView()
        .modelContainer(for: Expense.self, inMemory: true)
}
