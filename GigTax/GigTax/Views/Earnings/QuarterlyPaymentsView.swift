import SwiftUI
import SwiftData

struct QuarterlyPaymentsView: View {
    @Query private var shifts: [Shift]
    @Query private var trips: [Trip]
    @Query private var expenses: [Expense]
    @Query private var driverProfiles: [DriverProfile]
    @Query private var payments: [QuarterlyPayment]
    @Query private var vehicles: [Vehicle]
    @Environment(\.modelContext) private var modelContext

    @State private var showAddPayment = false
    @State private var taxYear = Calendar.current.component(.year, from: .now)

    private var driverProfile: DriverProfile? { driverProfiles.first }

    private var taxSummary: TaxSummary {
        TaxYearSummaryBuilder.build(shifts: shifts, trips: trips, expenses: expenses, driverProfile: driverProfile, taxYear: taxYear, vehicle: vehicles.first)
    }

    private var yearPayments: [QuarterlyPayment] {
        payments.filter { $0.taxYear == taxYear }.sorted { $0.quarterNumber < $1.quarterNumber }
    }
    private var paidSoFar: Double { yearPayments.reduce(0) { $0 + $1.amount } }

    private var remainingQuarters: [QuarterlyTaxCalculator.Quarter] {
        QuarterlyTaxCalculator.remainingQuarters(totalTaxOwed: taxSummary.totalTax, paidSoFar: paidSoFar, forYear: taxYear)
    }

    var body: some View {
        List {
            Section {
                LabeledContent("Total Owed", value: taxSummary.totalTax.formatted(.currency(code: "USD")))
                LabeledContent("Paid So Far", value: paidSoFar.formatted(.currency(code: "USD")))
                LabeledContent("Remaining", value: max(taxSummary.totalTax - paidSoFar, 0).formatted(.currency(code: "USD")))
            } header: {
                Text("Estimated Tax — \(String(taxYear))")
            } footer: {
                Text("Estimated from your logged shifts, trips, and expenses using your preferred deduction method. This updates automatically as you log more.")
            }

            if !remainingQuarters.isEmpty {
                Section("Upcoming Quarters") {
                    ForEach(remainingQuarters, id: \.number) { quarter in
                        QuarterlyDueRow(quarter: quarter)
                    }
                }
            }

            Section("Payments Logged") {
                if yearPayments.isEmpty {
                    Text("No payments logged yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(yearPayments) { payment in
                        NavigationLink {
                            QuarterlyPaymentEntryView(taxYear: taxYear, editing: payment)
                        } label: {
                            QuarterlyPaymentRow(payment: payment)
                        }
                    }
                    .onDelete(perform: delete)
                }
            }
        }
        .navigationTitle("Quarterly Taxes")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAddPayment = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("addQuarterlyPaymentButton")
                .accessibilityLabel("Add Payment")
            }
        }
        .sheet(isPresented: $showAddPayment) {
            QuarterlyPaymentEntryView(taxYear: taxYear)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(yearPayments[index]) }
    }
}

private struct QuarterlyDueRow: View {
    let quarter: QuarterlyTaxCalculator.Quarter

    var body: some View {
        HStack {
            Text("Q\(quarter.number)").fontWeight(.semibold)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(quarter.amountDue, format: .currency(code: "USD"))
                Text(quarter.dueDate, style: .date).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct QuarterlyPaymentRow: View {
    let payment: QuarterlyPayment

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Q\(payment.quarterNumber)").fontWeight(.semibold)
                Text(payment.date, style: .date).font(.caption).foregroundStyle(.secondary)
                if !payment.confirmationNumber.isEmpty {
                    Text("Conf# \(payment.confirmationNumber)").font(.caption2).foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(payment.amount, format: .currency(code: "USD")).fontWeight(.semibold)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

struct QuarterlyPaymentEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let taxYear: Int
    private let editing: QuarterlyPayment?

    @State private var quarterNumber: Int
    @State private var date: Date
    @State private var amountText: String
    @State private var confirmationNumber: String

    init(taxYear: Int, editing payment: QuarterlyPayment? = nil) {
        self.taxYear = taxYear
        editing = payment
        _quarterNumber = State(initialValue: payment?.quarterNumber ?? 1)
        _date = State(initialValue: payment?.date ?? Date())
        _amountText = State(initialValue: payment.map { $0.amount == 0 ? "" : String($0.amount) } ?? "")
        _confirmationNumber = State(initialValue: payment?.confirmationNumber ?? "")
    }

    private var amount: Double { Double(amountText) ?? 0 }
    private var canSave: Bool { amount > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Quarter", selection: $quarterNumber) {
                        Text("Q1").tag(1)
                        Text("Q2").tag(2)
                        Text("Q3").tag(3)
                        Text("Q4").tag(4)
                    }
                    .pickerStyle(.segmented)
                    DatePicker("Date Paid", selection: $date, displayedComponents: .date)
                    LabeledContent("Amount") {
                        TextField("0.00", text: $amountText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .accessibilityIdentifier("quarterlyPaymentAmountField")
                    }
                    TextField("IRS Confirmation Number", text: $confirmationNumber)
                        .autocorrectionDisabled()
                }
            }
            .navigationTitle(editing == nil ? "Log Payment" : "Edit Payment")
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
            existing.quarterNumber = quarterNumber
            existing.date = date
            existing.amount = amount
            existing.confirmationNumber = confirmationNumber
        } else {
            let payment = QuarterlyPayment(
                quarterNumber: quarterNumber,
                taxYear: taxYear,
                date: date,
                amount: amount,
                confirmationNumber: confirmationNumber
            )
            modelContext.insert(payment)
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        QuarterlyPaymentsView()
    }
    .modelContainer(for: QuarterlyPayment.self, inMemory: true)
}
