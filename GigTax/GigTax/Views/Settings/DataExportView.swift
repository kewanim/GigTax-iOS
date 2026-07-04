import SwiftUI
import SwiftData

struct DataExportView: View {
    @Query private var shifts: [Shift]
    @Query private var trips: [Trip]
    @Query private var expenses: [Expense]

    @State private var jsonURL: URL?
    @State private var shiftsCSVURL: URL?
    @State private var tripsCSVURL: URL?
    @State private var expensesCSVURL: URL?
    @State private var exportError = false

    var body: some View {
        List {
            Section {
                LabeledContent("Shifts", value: "\(shifts.count)")
                LabeledContent("Trips", value: "\(trips.count)")
                LabeledContent("Expenses", value: "\(expenses.count)")
            } header: {
                Text("What Gets Exported")
            }

            Section {
                Button("Prepare Export Files") {
                    prepareExports()
                }

                if let jsonURL {
                    ShareLink(item: jsonURL, preview: SharePreview("GigTax Backup.json")) {
                        Label("Full Backup (JSON)", systemImage: "doc.text")
                    }
                }
                if let shiftsCSVURL {
                    ShareLink(item: shiftsCSVURL, preview: SharePreview("Shifts.csv")) {
                        Label("Shifts (CSV)", systemImage: "tablecells")
                    }
                }
                if let tripsCSVURL {
                    ShareLink(item: tripsCSVURL, preview: SharePreview("Trips.csv")) {
                        Label("Trips (CSV)", systemImage: "tablecells")
                    }
                }
                if let expensesCSVURL {
                    ShareLink(item: expensesCSVURL, preview: SharePreview("Expenses.csv")) {
                        Label("Expenses (CSV)", systemImage: "tablecells")
                    }
                }
            } footer: {
                Text("The JSON backup contains every field needed to fully restore your data. CSVs open directly in Excel, Numbers, or Google Sheets.")
            }
        }
        .navigationTitle("Export Data")
        .alert("Export Failed", isPresented: $exportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Something went wrong preparing your export files. Please try again.")
        }
    }

    private func prepareExports() {
        let tempDir = FileManager.default.temporaryDirectory
        do {
            let jsonData = try DataExportGenerator.jsonData(shifts: shifts, trips: trips, expenses: expenses)
            let jsonFile = tempDir.appendingPathComponent("GigTax-Backup.json")
            try jsonData.write(to: jsonFile)
            jsonURL = jsonFile

            let shiftsFile = tempDir.appendingPathComponent("Shifts.csv")
            try DataExportGenerator.shiftsCSV(shifts).write(to: shiftsFile, atomically: true, encoding: .utf8)
            shiftsCSVURL = shiftsFile

            let tripsFile = tempDir.appendingPathComponent("Trips.csv")
            try DataExportGenerator.tripsCSV(trips).write(to: tripsFile, atomically: true, encoding: .utf8)
            tripsCSVURL = tripsFile

            let expensesFile = tempDir.appendingPathComponent("Expenses.csv")
            try DataExportGenerator.expensesCSV(expenses).write(to: expensesFile, atomically: true, encoding: .utf8)
            expensesCSVURL = expensesFile
        } catch {
            exportError = true
        }
    }
}

#Preview {
    NavigationStack {
        DataExportView()
    }
    .modelContainer(for: [Shift.self, Trip.self, Expense.self], inMemory: true)
}
