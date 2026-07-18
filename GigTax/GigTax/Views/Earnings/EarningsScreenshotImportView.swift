import SwiftUI
import SwiftData
import PhotosUI

/// Most drivers can screenshot their Uber/Lyft app's earnings summary but
/// can't export a CSV — this reads the screenshot with on-device OCR and
/// prefills an editable review form, since text recognition is inherently
/// approximate and every value here must be driver-confirmed before saving.
struct EarningsScreenshotImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(LocationService.self) private var locationService

    @State private var photosPickerItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var hasParsed = false
    @State private var errorMessage: String?
    @State private var isProcessing = false

    @State private var date = Date()
    @State private var platform = Platform.uber
    @State private var grossIncomeText = ""
    @State private var tipsText = ""
    @State private var hoursWorkedText = ""
    @State private var milesText = ""
    @State private var milesWasFoundByOCR = false
    @State private var estimateRateText = ""

    var body: some View {
        NavigationStack {
            Form {
                if let selectedImage {
                    Section {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                if isProcessing {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Reading screenshot…")
                        }
                    }
                } else if hasParsed {
                    reviewSection
                } else {
                    pickerSection
                }
            }
            .navigationTitle("Import Screenshot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                if hasParsed {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") { save() }.fontWeight(.semibold)
                    }
                }
            }
            .onChange(of: photosPickerItem) { _, newItem in
                Task { await process(newItem) }
            }
            .alert("Couldn't Read Screenshot", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
        }
    }

    private var pickerSection: some View {
        Section {
            PhotosPicker(selection: $photosPickerItem, matching: .images) {
                Label("Choose Screenshot", systemImage: "photo.badge.plus")
            }
        } footer: {
            Text("Select a screenshot of your weekly (or daily) earnings summary from the Uber or Lyft driver app. GigTax reads the numbers and lets you confirm them before saving.")
        }
    }

    @ViewBuilder
    private var reviewSection: some View {
        Section {
            DatePicker("Date", selection: $date, displayedComponents: .date)
            Picker("Platform", selection: $platform) {
                ForEach(Platform.allCases, id: \.self) { p in
                    Text(p.rawValue).tag(p)
                }
            }
            LabeledContent("Gross Income") {
                TextField("$", text: $grossIncomeText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Tips") {
                TextField("$", text: $tipsText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Hours Worked") {
                TextField("0", text: $hoursWorkedText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Miles") {
                TextField("0", text: $milesText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("Review & Confirm")
        } footer: {
            Text("Double check these against your screenshot above — extracted values aren't always perfect.")
        }

        if !milesWasFoundByOCR {
            Section {
                LabeledContent("$1 ≈") {
                    HStack(spacing: 4) {
                        TextField("0.0", text: $estimateRateText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .onChange(of: estimateRateText) { _, _ in updateEstimatedMiles() }
                        Text("mi").foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Estimate Mileage")
            } footer: {
                Text("This screenshot doesn't show mileage. Enter your typical earnings-per-mile rate and GigTax will estimate miles driven from your gross income — or just type the exact miles above if you know it.")
            }
        }
    }

    private func process(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                errorMessage = "Couldn't load that image."
                return
            }
            selectedImage = image
            let lines = try EarningsScreenshotParser.recognizeText(in: image)
            let result = EarningsScreenshotParser.parse(lines: lines)
            seedFields(from: result)
            hasParsed = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func seedFields(from result: ParsedWeeklyEarnings) {
        if let parsedPlatform = result.platform { platform = parsedPlatform }
        date = result.endDate ?? result.startDate ?? .now
        grossIncomeText = result.grossIncome.map { String(format: "%.2f", $0) } ?? ""
        tipsText = result.tips.map { String(format: "%.2f", $0) } ?? ""
        hoursWorkedText = result.hoursWorked.map { String(format: "%.2f", $0) } ?? ""
        milesWasFoundByOCR = result.miles != nil
        milesText = result.miles.map { String(format: "%.1f", $0) } ?? ""
    }

    private func updateEstimatedMiles() {
        guard let rate = Double(estimateRateText), rate > 0 else { return }
        let gross = Double(grossIncomeText) ?? 0
        milesText = String(format: "%.1f", gross * rate)
    }

    private func save() {
        let shift = Shift(
            date: date,
            platform: platform,
            grossIncome: Double(grossIncomeText) ?? 0,
            tips: Double(tipsText) ?? 0,
            hoursWorked: Double(hoursWorkedText) ?? 0,
            importSource: "\(platform.rawValue.lowercased().replacingOccurrences(of: " ", with: "_"))_screenshot"
        )
        if let selectedImage, let data = selectedImage.jpegData(compressionQuality: 0.8) {
            shift.screenshotImagePath = ReceiptStorage.save(data: data, fileExtension: "jpg")
        }
        modelContext.insert(shift)

        if let miles = Double(milesText), miles > 0 {
            // Real or estimated mileage from the screenshot needs to be a real
            // Trip, not just a cosmetic field, or it never reaches the actual
            // standard-mileage deduction — same 55/45 city/highway split
            // ManualTripEntryView uses, since a screenshot has no GPS split to work from.
            let cityMiles = miles * 0.55
            let highwayMiles = miles * 0.45
            let gallons = (locationService.cityMPG > 0 ? cityMiles / locationService.cityMPG : 0)
                        + (locationService.highwayMPG > 0 ? highwayMiles / locationService.highwayMPG : 0)

            let trip = Trip(startDate: date, isManualEntry: true)
            trip.endDate = date
            trip.distanceMiles = miles
            trip.cityMiles = cityMiles
            trip.highwayMiles = highwayMiles
            trip.tripTypeRaw = TripType.business.rawValue
            trip.businessPurpose = "\(platform.rawValue) — estimated from earnings import"
            trip.estimatedFuelGallons = gallons
            trip.estimatedFuelCost = gallons * locationService.gasPrice

            modelContext.insert(trip)
            if let fuelExpense = Expense.fuelExpense(for: trip) {
                modelContext.insert(fuelExpense)
            }
            shift.linkedTripID = trip.id

            if let vehicle = locationService.vehicle {
                MaintenanceScheduler.evaluate(vehicle: vehicle, modelContext: modelContext)
            }
        }

        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    EarningsScreenshotImportView()
        .modelContainer(for: Shift.self, inMemory: true)
        .environment(LocationService())
}
