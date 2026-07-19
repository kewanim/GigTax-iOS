import SwiftUI
import SwiftData

private enum GroupMode: String, CaseIterable {
    case month = "By Month"
    case category = "By Category"
}

struct ExpensesView: View {
    @Query(sort: \Expense.date, order: .reverse) private var expenses: [Expense]
    @Query private var recurringExpenses: [RecurringExpense]
    @Query private var driverProfiles: [DriverProfile]
    @Environment(\.modelContext) private var modelContext

    @State private var showManualEntry = false
    @State private var groupMode = GroupMode.month
    @State private var categoryFilter: ExpenseCategory?

    private var phoneBusinessPercent: Double { driverProfiles.first?.phoneBusinessPercent ?? 100 }
    private var currentYear: Int { Calendar.current.component(.year, from: .now) }
    private var ytdExpenses: [Expense] { expenses.filter { $0.taxYear == currentYear } }

    private var categoryTotals: [(category: ExpenseCategory, total: Double)] {
        var totals: [ExpenseCategory: Double] = [:]
        for expense in ytdExpenses { totals[expense.category, default: 0] += expense.amount }
        // Not filtered by isActive — proRatedTotal is already correctly
        // date-bound (via startDate/endDate), and something paused mid-year
        // still legitimately contributed to this year's total before it stopped.
        for recurring in recurringExpenses {
            totals[recurring.category, default: 0] += recurring.proRatedTotal(forTaxYear: currentYear)
        }
        return totals.map { (category: $0.key, total: $0.value) }.sorted { $0.total > $1.total }
    }

    private var filteredExpenses: [Expense] {
        guard let categoryFilter else { return expenses }
        return expenses.filter { $0.category == categoryFilter }
    }

    var body: some View {
        NavigationStack {
            List {
                // Always reachable, regardless of whether any expenses exist yet —
                // a fresh install with zero expenses still needs a way in to set up
                // the vehicle and recurring costs.
                Section {
                    NavigationLink {
                        RecurringExpensesView()
                    } label: {
                        Label("Recurring Expenses", systemImage: "arrow.clockwise")
                    }
                    NavigationLink {
                        VehicleDetailsView()
                    } label: {
                        Label("Vehicle Details", systemImage: "car.fill")
                    }
                }

                if expenses.isEmpty {
                    ContentUnavailableView(
                        "No expenses yet",
                        systemImage: "receipt",
                        description: Text("Fuel logs automatically after each business trip. Add anything else here.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    Section("This Year") {
                        ForEach(categoryTotals, id: \.category) { entry in
                            HStack {
                                Label(entry.category.rawValue, systemImage: entry.category.icon)
                                Spacer()
                                Text(entry.total, format: .currency(code: "USD"))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    Section {
                        Picker("Group by", selection: $groupMode) {
                            ForEach(GroupMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        Menu {
                            Button("All Categories") { categoryFilter = nil }
                            ForEach(ExpenseCategory.allCases, id: \.self) { c in
                                Button(c.rawValue) { categoryFilter = c }
                            }
                        } label: {
                            Label(categoryFilter?.rawValue ?? "All Categories", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }

                    if groupMode == .month {
                        ForEach(groupedByMonth, id: \.month) { group in
                            Section(header: sectionHeader(Text(group.month, format: .dateTime.month(.wide).year()), total: group.expenses.reduce(0) { $0 + $1.amount })) {
                                ForEach(group.expenses) { expense in
                                    NavigationLink {
                                        ManualExpenseEntryView(editing: expense)
                                    } label: {
                                        ExpenseRow(expense: expense, phoneBusinessPercent: phoneBusinessPercent)
                                    }
                                }
                                .onDelete { offsets in delete(group.expenses, at: offsets) }
                            }
                        }
                    } else {
                        ForEach(groupedByCategory, id: \.category) { group in
                            Section(header: sectionHeader(Text(group.category.rawValue), total: group.expenses.reduce(0) { $0 + $1.amount })) {
                                ForEach(group.expenses) { expense in
                                    NavigationLink {
                                        ManualExpenseEntryView(editing: expense)
                                    } label: {
                                        ExpenseRow(expense: expense, phoneBusinessPercent: phoneBusinessPercent)
                                    }
                                }
                                .onDelete { offsets in delete(group.expenses, at: offsets) }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Expenses")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showManualEntry = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityIdentifier("addExpenseButton")
                    .accessibilityLabel("Add Expense")
                }
            }
            .sheet(isPresented: $showManualEntry) {
                ManualExpenseEntryView()
            }
        }
    }

    private func sectionHeader(_ title: Text, total: Double) -> some View {
        HStack {
            title
            Spacer()
            Text(total, format: .currency(code: "USD")).textCase(nil)
        }
        .accessibilityElement(children: .combine)
    }

    private var groupedByMonth: [(month: Date, expenses: [Expense])] {
        let calendar = Calendar.current
        let dict = Dictionary(grouping: filteredExpenses) { expense in
            calendar.date(from: calendar.dateComponents([.year, .month], from: expense.date)) ?? expense.date
        }
        return dict.keys.sorted(by: >).map { (month: $0, expenses: dict[$0]!) }
    }

    private var groupedByCategory: [(category: ExpenseCategory, expenses: [Expense])] {
        let dict = Dictionary(grouping: filteredExpenses, by: \.category)
        return dict.keys.sorted { $0.rawValue < $1.rawValue }.map { (category: $0, expenses: dict[$0]!) }
    }

    private func delete(_ expensesInSection: [Expense], at offsets: IndexSet) {
        for index in offsets { modelContext.delete(expensesInSection[index]) }
    }
}

private struct ExpenseRow: View {
    let expense: Expense
    let phoneBusinessPercent: Double

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: expense.category.icon).foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(expense.category.rawValue).font(.subheadline).fontWeight(.semibold)
                Text(expense.date, style: .date).font(.caption).foregroundStyle(.secondary)
                if expense.category == .phone {
                    Text("\(Int(phoneBusinessPercent))% business — \(expense.deductibleAmount(phoneBusinessPercent: phoneBusinessPercent).formatted(.currency(code: "USD"))) deductible")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(expense.amount, format: .currency(code: "USD"))
                    .font(.subheadline).fontWeight(.semibold)
                if expense.receiptImagePath != nil {
                    Image(systemName: "paperclip").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    ExpensesView()
        .modelContainer(for: Expense.self, inMemory: true)
}
