import SwiftUI
import SwiftData

struct RecurringExpensesView: View {
    @Query private var recurringExpenses: [RecurringExpense]
    @Environment(\.modelContext) private var modelContext
    @State private var showAdd = false

    var body: some View {
        List {
            if recurringExpenses.isEmpty {
                ContentUnavailableView(
                    "No recurring expenses",
                    systemImage: "arrow.clockwise.circle",
                    description: Text("Add phone bills, cleaning services, or anything else you pay regularly.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(recurringExpenses) { recurring in
                    NavigationLink {
                        RecurringExpenseEntryView(editing: recurring)
                    } label: {
                        RecurringExpenseRow(recurring: recurring)
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Recurring Expenses")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            RecurringExpenseEntryView()
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(recurringExpenses[index]) }
    }
}

private struct RecurringExpenseRow: View {
    let recurring: RecurringExpense

    var body: some View {
        HStack {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: recurring.category.icon).foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(recurring.category.rawValue).font(.subheadline).fontWeight(.semibold)
                Text("\(recurring.amount.formatted(.currency(code: "USD"))) / \(recurring.frequency.rawValue.lowercased())")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if !recurring.isActive {
                Text("Paused").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct RecurringExpenseEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    private let editing: RecurringExpense?

    @State private var category: ExpenseCategory
    @State private var amountText: String
    @State private var frequency: RecurringFrequency
    @State private var startDate: Date
    @State private var isActive: Bool

    init(editing recurring: RecurringExpense? = nil) {
        editing = recurring
        _category = State(initialValue: recurring?.category ?? .phone)
        _amountText = State(initialValue: recurring.map { $0.amount == 0 ? "" : String($0.amount) } ?? "")
        _frequency = State(initialValue: recurring?.frequency ?? .monthly)
        _startDate = State(initialValue: recurring?.startDate ?? Date())
        _isActive = State(initialValue: recurring?.isActive ?? true)
    }

    private var amount: Double { Double(amountText) ?? 0 }
    private var canSave: Bool { amount > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(ExpenseCategory.allCases, id: \.self) { c in
                            Label(c.rawValue, systemImage: c.icon).tag(c)
                        }
                    }
                    LabeledContent("Amount") {
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    Picker("Frequency", selection: $frequency) {
                        ForEach(RecurringFrequency.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Starting", selection: $startDate, displayedComponents: .date)
                }

                if editing != nil {
                    Section {
                        Toggle("Active", isOn: $isActive)
                    } footer: {
                        Text("Pause instead of deleting to keep past pro-rated totals accurate.")
                    }
                }
            }
            .navigationTitle(editing == nil ? "Add Recurring" : "Edit Recurring")
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
        if let existing = editing {
            existing.category = category
            existing.amount = amount
            existing.frequency = frequency
            existing.startDate = startDate
            existing.isActive = isActive
        } else {
            let recurring = RecurringExpense(category: category, amount: amount, frequency: frequency, startDate: startDate)
            modelContext.insert(recurring)
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        RecurringExpensesView()
    }
    .modelContainer(for: RecurringExpense.self, inMemory: true)
}
