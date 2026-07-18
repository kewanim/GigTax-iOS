import SwiftUI
import SwiftData

struct VehicleDetailsView: View {
    @Query private var vehicles: [Vehicle]
    @Query private var trips: [Trip]
    @Environment(\.modelContext) private var modelContext

    @State private var ownership: VehicleOwnership = .owned
    @State private var purchasePriceText = ""
    @State private var loanTermText = ""
    @State private var loanAPRText = ""
    @State private var loanStartDate = Date()
    @State private var weeklyReminderOn = false

    private var vehicle: Vehicle? { vehicles.first }

    var body: some View {
        Group {
            if let vehicle {
                Form {
                    ownershipSection(vehicle: vehicle)
                    maintenanceLinkSection
                    odometerSection(vehicle: vehicle)
                }
            } else {
                ContentUnavailableView("No vehicle yet", systemImage: "car", description: Text("Finish onboarding to add your car first."))
            }
        }
        .navigationTitle("Vehicle Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadFromVehicle() }
        .onChange(of: purchasePriceText) { _, newValue in vehicle?.purchasePrice = Double(newValue) }
        .onChange(of: loanTermText) { _, newValue in vehicle?.loanTermMonths = Int(newValue) }
        .onChange(of: loanAPRText) { _, newValue in vehicle?.loanAPR = Double(newValue) }
        .onChange(of: loanStartDate) { _, newValue in vehicle?.loanStartDate = newValue }
    }

    @ViewBuilder
    private func ownershipSection(vehicle: Vehicle) -> some View {
        Section {
            Picker("This car is", selection: $ownership) {
                ForEach(VehicleOwnership.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .onChange(of: ownership) { _, newValue in vehicle.ownership = newValue }

            ownershipFields
        } header: {
            Text("Ownership")
        } footer: {
            financingFooter
        }
    }

    @ViewBuilder
    private var financingFooter: some View {
        if ownership == .financing {
            Text(interestFooterText)
        }
    }

    private var maintenanceLinkSection: some View {
        Section {
            NavigationLink {
                MaintenanceScheduleView()
            } label: {
                Label("Maintenance Schedule", systemImage: "wrench.and.screwdriver.fill")
            }
        }
    }

    @ViewBuilder
    private func odometerSection(vehicle: Vehicle) -> some View {
        Section {
            LabeledContent("Estimated Current", value: "\(Int(estimatedOdometer)) mi")
            lastConfirmedRow(vehicle: vehicle)
            NavigationLink {
                OdometerCheckInView(vehicle: vehicle)
            } label: {
                Label("Confirm Odometer", systemImage: "gauge.with.dots.needle.67percent")
            }
            Toggle("Weekly Reminder", isOn: $weeklyReminderOn)
                .onChange(of: weeklyReminderOn) { _, isOn in toggleWeeklyReminder(isOn) }
        } header: {
            Text("Odometer")
        } footer: {
            Text("GPS-tracked mileage drifts from your car's true odometer over time. A weekly check-in keeps maintenance reminders accurate.")
        }
    }

    private func lastConfirmedRow(vehicle: Vehicle) -> some View {
        LabeledContent("Last Confirmed") {
            VStack(alignment: .trailing) {
                Text("\(Int(vehicle.lastConfirmedOdometer)) mi")
                Text(vehicle.lastConfirmedOdometerDate, style: .date)
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var estimatedOdometer: Double {
        guard let vehicle else { return 0 }
        return OdometerReconciliation.estimatedCurrentOdometer(vehicle: vehicle, completedTrips: trips)
    }

    @ViewBuilder
    private var ownershipFields: some View {
        switch ownership {
        case .financing:
            FinancingFieldsSection(purchasePriceText: $purchasePriceText, loanTermText: $loanTermText, loanAPRText: $loanAPRText, loanStartDate: $loanStartDate)
        case .leasing:
            LeasingNoteView()
        case .owned:
            EmptyView()
        }
    }

    private var interestFooterText: String {
        let amount = estimatedInterestThisYear.formatted(.currency(code: "USD"))
        return "Total loan interest paid this year: \(amount). Only the business-use share of this is deductible — that % gets applied when the tax summary is built."
    }

    private var estimatedInterestThisYear: Double {
        guard let vehicle, let principal = vehicle.purchasePrice, let apr = vehicle.loanAPR,
              let term = vehicle.loanTermMonths, let start = vehicle.loanStartDate else { return 0 }
        return LoanInterestCalculator.interestPaid(
            principal: principal, apr: apr, termMonths: term, startDate: start,
            forYear: Calendar.current.component(.year, from: .now)
        )
    }

    private func loadFromVehicle() {
        guard let vehicle else { return }
        ownership = vehicle.ownership
        purchasePriceText = vehicle.purchasePrice.map { $0 == 0 ? "" : String($0) } ?? ""
        loanTermText = vehicle.loanTermMonths.map(String.init) ?? ""
        loanAPRText = vehicle.loanAPR.map { String($0) } ?? ""
        loanStartDate = vehicle.loanStartDate ?? Date()
    }

    private func toggleWeeklyReminder(_ isOn: Bool) {
        if isOn {
            Task {
                let granted = await NotificationManager.requestAuthorizationIfNeeded()
                if granted {
                    NotificationManager.scheduleWeeklyOdometerCheckIn()
                } else {
                    weeklyReminderOn = false
                }
            }
        } else {
            NotificationManager.cancelWeeklyOdometerCheckIn()
        }
    }
}

private struct FinancingFieldsSection: View {
    @Binding var purchasePriceText: String
    @Binding var loanTermText: String
    @Binding var loanAPRText: String
    @Binding var loanStartDate: Date

    var body: some View {
        LabeledContent("Purchase Price") {
            TextField("0", text: $purchasePriceText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
        LabeledContent("Loan Term (months)") {
            TextField("60", text: $loanTermText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
        }
        LabeledContent("Interest Rate (APR %)") {
            TextField("6.5", text: $loanAPRText)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
        }
        DatePicker("Loan Started", selection: $loanStartDate, displayedComponents: .date)
    }
}

private struct LeasingNoteView: View {
    var body: some View {
        Text("Lease payments aren't tracked here yet — log your monthly lease payment as a Recurring Expense instead.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

#Preview {
    NavigationStack {
        VehicleDetailsView()
    }
    .modelContainer(for: Vehicle.self, inMemory: true)
}
