import SwiftUI
import SwiftData

struct TripsView: View {
    @Environment(LocationService.self) private var locationService
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]
    @State private var showManualEntry = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        MileageLogView(taxYear: Calendar.current.component(.year, from: .now))
                    } label: {
                        Label("Mileage Log", systemImage: "list.bullet.rectangle")
                    }
                    NavigationLink {
                        AuditShieldView()
                    } label: {
                        Label("Audit Shield", systemImage: "checkmark.shield")
                    }
                }

                if locationService.isTracking {
                    Section {
                        ActiveTripBanner(service: locationService)
                    }
                }

                if trips.isEmpty && !locationService.isTracking {
                    ContentUnavailableView(
                        "No trips yet",
                        systemImage: "car.fill",
                        description: Text("GigTax will auto-detect trips when you drive. You can also log one manually.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(groupedByDay, id: \.date) { group in
                        Section(header: Text(group.date, style: .date)) {
                            ForEach(group.trips) { trip in
                                NavigationLink { TripDetailView(trip: trip) } label: {
                                    TripRow(trip: trip)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Trips")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showManualEntry = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Log Trip")
                }
            }
            .sheet(isPresented: $showManualEntry) {
                ManualTripEntryView()
            }
        }
    }

    private var groupedByDay: [(date: Date, trips: [Trip])] {
        let cal = Calendar.current
        let dict = Dictionary(grouping: trips) { cal.startOfDay(for: $0.startDate) }
        return dict.keys.sorted(by: >).map { (date: $0, trips: dict[$0]!) }
    }
}

// MARK: - Active trip banner

private struct ActiveTripBanner: View {
    let service: LocationService

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(Color.green.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: "car.fill").foregroundStyle(.green)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Trip in progress")
                    .font(.subheadline).fontWeight(.semibold)
                HStack(spacing: 8) {
                    Text(String(format: "%.1f mi", service.currentTripMiles))
                        .font(.caption).foregroundStyle(.secondary)
                    if let start = service.currentTripStart {
                        Text("· \(start, style: .relative) ago")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Circle().fill(.green).frame(width: 8, height: 8)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Trip row

private struct TripRow: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(trip.startDate, style: .time)
                    .font(.subheadline).fontWeight(.semibold)
                if trip.isManualEntry {
                    Text("Manual").font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.tertiary).clipShape(Capsule())
                }
                Spacer()
                Text(String(format: "%.1f mi", trip.distanceMiles))
                    .font(.subheadline).fontWeight(.semibold)
            }
            HStack {
                Label(
                    trip.tripType == .business ? "Business" : "Personal",
                    systemImage: trip.tripType == .business ? "briefcase.fill" : "house.fill"
                )
                .font(.caption)
                .foregroundStyle(trip.tripType == .business ? Color.accentColor : .secondary)
                Spacer()
                if trip.estimatedFuelCost > 0 {
                    Text(trip.estimatedFuelCost, format: .currency(code: "USD"))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    TripsView()
        .environment(LocationService())
        .modelContainer(for: Trip.self, inMemory: true)
}
