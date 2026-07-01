import SwiftUI
import MapKit
import SwiftData

struct TripDetailView: View {
    @Bindable var trip: Trip
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var mapPosition: MapCameraPosition = .automatic
    @State private var confirmDelete = false

    var body: some View {
        List {
            // Map
            Section {
                Map(position: $mapPosition) {
                    if trip.startLatitude != 0 || trip.startLongitude != 0 {
                        Marker("Start", coordinate: CLLocationCoordinate2D(
                            latitude: trip.startLatitude, longitude: trip.startLongitude))
                            .tint(.green)
                    }
                    if let lat = trip.endLatitude, let lon = trip.endLongitude {
                        Marker("End", coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))
                            .tint(.red)
                    }
                }
                .frame(height: 220)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .listRowInsets(.init())

            // Stats
            Section("Trip Details") {
                LabeledContent("Distance") {
                    Text(String(format: "%.2f mi", trip.distanceMiles))
                }
                LabeledContent("Duration") {
                    Text(formatDuration(trip.durationSeconds))
                }
                LabeledContent("City Miles") {
                    Text(String(format: "%.1f mi  (%.0f%%)",
                                trip.cityMiles,
                                trip.distanceMiles > 0 ? trip.cityMiles / trip.distanceMiles * 100 : 0))
                }
                LabeledContent("Highway Miles") {
                    Text(String(format: "%.1f mi  (%.0f%%)",
                                trip.highwayMiles,
                                trip.distanceMiles > 0 ? trip.highwayMiles / trip.distanceMiles * 100 : 0))
                }
                if trip.isManualEntry {
                    LabeledContent("Entry") { Text("Manual") }
                }
            }

            Section("Fuel Cost") {
                LabeledContent("Gallons Used") {
                    Text(String(format: "%.3f gal", trip.estimatedFuelGallons))
                }
                LabeledContent("Estimated Cost") {
                    Text(trip.estimatedFuelCost, format: .currency(code: "USD"))
                        .fontWeight(.semibold)
                }
            }

            Section("Classification") {
                Picker("Type", selection: $trip.tripTypeRaw) {
                    Text("Business").tag(TripType.business.rawValue)
                    Text("Personal").tag(TripType.personal.rawValue)
                }
                .pickerStyle(.segmented)
                if trip.tripType == .business {
                    TextField("Business purpose (optional)", text: $trip.businessPurpose)
                        .autocorrectionDisabled()
                }
            }

            Section {
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Delete Trip", systemImage: "trash")
                }
            }
        }
        .navigationTitle(trip.startDate.formatted(date: .abbreviated, time: .shortened))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Delete this trip?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(trip)
                dismiss()
            }
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m) min"
    }
}
