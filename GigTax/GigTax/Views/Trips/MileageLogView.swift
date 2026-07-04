import SwiftUI
import SwiftData

struct MileageLogView: View {
    @Query(sort: \Trip.startDate, order: .reverse) private var allTrips: [Trip]

    let taxYear: Int

    @State private var searchText = ""
    @State private var sortOption: SortOption = .dateDescending
    @State private var editingTrip: Trip?

    enum SortOption: String, CaseIterable {
        case dateDescending = "Newest First"
        case dateAscending = "Oldest First"
        case milesDescending = "Most Miles"
    }

    private var yearTrips: [Trip] {
        allTrips.filter { $0.taxYear == taxYear && $0.isComplete }
    }

    var filteredTrips: [Trip] {
        let base = searchText.isEmpty ? yearTrips : yearTrips.filter { trip in
            trip.businessPurpose.localizedCaseInsensitiveContains(searchText)
                || (trip.startAddress?.localizedCaseInsensitiveContains(searchText) ?? false)
                || (trip.endAddress?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
        switch sortOption {
        case .dateDescending: return base.sorted { $0.startDate > $1.startDate }
        case .dateAscending: return base.sorted { $0.startDate < $1.startDate }
        case .milesDescending: return base.sorted { $0.distanceMiles > $1.distanceMiles }
        }
    }

    var body: some View {
        List {
            if filteredTrips.isEmpty {
                ContentUnavailableView(
                    "No trips logged",
                    systemImage: "map",
                    description: Text("Completed trips for \(String(taxYear)) will appear here.")
                )
            } else {
                ForEach(filteredTrips) { trip in
                    Button {
                        editingTrip = trip
                    } label: {
                        MileageLogRow(trip: trip)
                    }
                    .buttonStyle(.plain)
                    .task { await TripGeocoder.resolveAddressesIfNeeded(for: trip) }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search purpose or address")
        .navigationTitle("Mileage Log")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Picker("Sort", selection: $sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            }
        }
        .sheet(item: $editingTrip) { trip in
            MileageLogEntryEditView(trip: trip)
        }
    }
}

private struct MileageLogRow: View {
    let trip: Trip

    private var route: String {
        let origin = trip.startAddress ?? String(format: "%.3f, %.3f", trip.startLatitude, trip.startLongitude)
        if let endAddress = trip.endAddress {
            return "\(origin) → \(endAddress)"
        } else if let endLat = trip.endLatitude, let endLon = trip.endLongitude {
            return "\(origin) → \(String(format: "%.3f, %.3f", endLat, endLon))"
        }
        return origin
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(trip.startDate, style: .date)
                    .font(.subheadline)
                Spacer()
                Text("\(trip.distanceMiles, specifier: "%.1f") mi")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            Text(route)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if trip.businessPurpose.isEmpty {
                Label("Missing business purpose", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            } else {
                Text(trip.businessPurpose)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

private struct MileageLogEntryEditView: View {
    @Environment(\.dismiss) private var dismiss
    let trip: Trip

    @State private var businessPurpose: String
    @State private var tripType: TripType

    init(trip: Trip) {
        self.trip = trip
        _businessPurpose = State(initialValue: trip.businessPurpose)
        _tripType = State(initialValue: trip.tripType)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Trip Type") {
                    Picker("Type", selection: $tripType) {
                        Text("Business").tag(TripType.business)
                        Text("Personal").tag(TripType.personal)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Business Purpose") {
                    TextField("e.g. Uber driving, DoorDash delivery", text: $businessPurpose, axis: .vertical)
                }
            }
            .navigationTitle("Edit Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        trip.businessPurpose = businessPurpose
                        trip.tripType = tripType
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MileageLogView(taxYear: Calendar.current.component(.year, from: .now))
    }
    .modelContainer(for: Trip.self, inMemory: true)
}
