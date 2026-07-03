import SwiftUI
import SwiftData

/// "Did you get it done? What did it cost?" — reachable from the due/follow-up
/// notification or manually from the maintenance list. Logging here both
/// creates the linked expense and personalizes the cost estimate going forward.
struct LogServiceView: View {
    let item: MaintenanceScheduleItem
    let estimatedOdometer: Double

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var costText: String

    init(item: MaintenanceScheduleItem, estimatedOdometer: Double) {
        self.item = item
        self.estimatedOdometer = estimatedOdometer
        _costText = State(initialValue: String(Int(item.estimatedCost)))
    }

    private var cost: Double { Double(costText) ?? 0 }
    private var canSave: Bool { cost > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Service", value: item.type.rawValue)
                    LabeledContent("At", value: "\(Int(estimatedOdometer)) mi")
                    LabeledContent("What did it cost?") {
                        TextField("\(Int(item.estimatedCost))", text: $costText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                } footer: {
                    Text("This logs a maintenance expense and updates GigTax's cost estimate for next time, based on what you actually paid.")
                }
            }
            .navigationTitle("Log Service")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Not Yet") { dismiss() }
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
        item.recordService(atMileage: estimatedOdometer, cost: cost)

        let expense = Expense.maintenanceExpense(for: item, actualCost: cost)
        modelContext.insert(expense)

        NotificationManager.cancelMaintenanceFollowUp(item: item)
        dismiss()
    }
}

#Preview {
    LogServiceView(item: MaintenanceScheduleItem(), estimatedOdometer: 45_000)
        .modelContainer(for: MaintenanceScheduleItem.self, inMemory: true)
}
