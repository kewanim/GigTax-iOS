import SwiftUI

struct ExpensesView: View {
    var body: some View {
        NavigationStack {
            Text("Expense tracking coming in S4")
                .foregroundStyle(.secondary)
                .navigationTitle("Expenses")
        }
    }
}

#Preview {
    ExpensesView()
}
