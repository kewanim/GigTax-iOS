import SwiftUI
import SwiftData

struct MaintenanceScheduleView: View {
    @Query private var items: [MaintenanceScheduleItem]
    @Query private var vehicles: [Vehicle]
    @Query private var trips: [Trip]
    @Environment(\.modelContext) private var modelContext
    @State private var showAdd = false
    @State private var loggingItem: MaintenanceScheduleItem?

    private var estimatedOdometer: Double {
        guard let vehicle = vehicles.first else { return 0 }
        return OdometerReconciliation.estimatedCurrentOdometer(vehicle: vehicle, completedTrips: trips)
    }

    var body: some View {
        List {
            if items.isEmpty {
                ContentUnavailableView(
                    "No maintenance items yet",
                    systemImage: "wrench.and.screwdriver",
                    description: Text("Add your car's own service intervals — oil changes, tire replacement, whatever your owner's manual recommends. GigTax will remind you as the mileage gets close.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(items) { item in
                    Button {
                        loggingItem = item
                    } label: {
                        MaintenanceRow(item: item, estimatedOdometer: estimatedOdometer)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button("Log Service") { loggingItem = item }.tint(.accentColor)
                    }
                }
                .onDelete(perform: delete)
            }
        }
        .navigationTitle("Maintenance Schedule")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showAdd = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityIdentifier("addMaintenanceItemButton")
                .accessibilityLabel("Add Maintenance Item")
            }
        }
        .sheet(isPresented: $showAdd) {
            MaintenanceScheduleItemEntryView()
        }
        .sheet(item: $loggingItem) { item in
            LogServiceView(item: item, estimatedOdometer: estimatedOdometer)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { modelContext.delete(items[index]) }
    }
}

private struct MaintenanceRow: View {
    let item: MaintenanceScheduleItem
    let estimatedOdometer: Double

    private var milesRemaining: Double { item.milesRemaining(estimatedCurrentOdometer: estimatedOdometer) }
    private var isDue: Bool { milesRemaining <= 0 }

    var body: some View {
        HStack {
            ZStack {
                Circle().fill((isDue ? Color.orange : Color.accentColor).opacity(0.12)).frame(width: 36, height: 36)
                Image(systemName: item.type.icon).foregroundStyle(isDue ? .orange : Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.type.rawValue).font(.subheadline).fontWeight(.semibold)
                Text("Every \(Int(item.intervalMiles)) mi · ~\(item.estimatedCost.formatted(.currency(code: "USD")))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if isDue {
                Text("Due now").font(.caption2).fontWeight(.semibold)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.orange.opacity(0.15)).foregroundStyle(.orange).clipShape(Capsule())
            } else {
                Text("\(Int(milesRemaining)) mi left").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

struct MaintenanceScheduleItemEntryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var vehicles: [Vehicle]

    private let editing: MaintenanceScheduleItem?

    @State private var type: MaintenanceType
    @State private var intervalMilesText: String
    @State private var estimatedCostText: String
    @State private var lastServiceMileageText: String
    @State private var isActive: Bool

    init(editing item: MaintenanceScheduleItem? = nil) {
        editing = item
        _type = State(initialValue: item?.type ?? .oilChange)
        _intervalMilesText = State(initialValue: String(Int(item?.intervalMiles ?? MaintenanceType.oilChange.defaultIntervalMiles)))
        _estimatedCostText = State(initialValue: String(Int(item?.estimatedCost ?? MaintenanceType.oilChange.defaultEstimatedCost)))
        _lastServiceMileageText = State(initialValue: String(Int(item?.lastServiceMileage ?? 0)))
        _isActive = State(initialValue: item?.isActive ?? true)
    }

    private var intervalMiles: Double { Double(intervalMilesText) ?? 0 }
    private var estimatedCost: Double { Double(estimatedCostText) ?? 0 }
    private var lastServiceMileage: Double { Double(lastServiceMileageText) ?? 0 }
    private var canSave: Bool { intervalMiles > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Service", selection: $type) {
                        ForEach(MaintenanceType.allCases, id: \.self) { t in
                            Label(t.rawValue, systemImage: t.icon).tag(t)
                        }
                    }
                    .onChange(of: type) { _, newType in
                        // Only reset to the new type's defaults if the driver hasn't
                        // already customized these fields for a fresh entry.
                        if editing == nil {
                            intervalMilesText = String(Int(newType.defaultIntervalMiles))
                            estimatedCostText = String(Int(newType.defaultEstimatedCost))
                        }
                    }
                    LabeledContent("Interval") {
                        TextField("5000", text: $intervalMilesText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("mi").foregroundStyle(.secondary)
                    }
                    LabeledContent("Estimated Cost") {
                        TextField("60", text: $estimatedCostText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Last Done At") {
                        TextField("0", text: $lastServiceMileageText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                        Text("mi").foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("These are just a starting point — set them to match your own car's owner's manual and what things actually cost you. GigTax updates the cost estimate automatically once you log a real one.")
                }

                if editing != nil {
                    Section {
                        Toggle("Active", isOn: $isActive)
                    }
                }
            }
            .navigationTitle(editing == nil ? "Add Maintenance Item" : "Edit Maintenance Item")
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
            existing.type = type
            existing.intervalMiles = intervalMiles
            existing.estimatedCost = estimatedCost
            existing.lastServiceMileage = lastServiceMileage
            existing.isActive = isActive
        } else {
            let vehicleID: UUID? = vehicles.first?.id
            let interval: Double? = intervalMiles
            let cost: Double? = estimatedCost
            let mileage: Double = lastServiceMileage
            let item = MaintenanceScheduleItem(
                vehicleID: vehicleID,
                type: type,
                intervalMiles: interval,
                estimatedCost: cost,
                lastServiceMileage: mileage
            )
            modelContext.insert(item)
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        MaintenanceScheduleView()
    }
    .modelContainer(for: MaintenanceScheduleItem.self, inMemory: true)
}
