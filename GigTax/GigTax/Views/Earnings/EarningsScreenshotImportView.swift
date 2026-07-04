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
        } header: {
            Text("Review & Confirm")
        } footer: {
            Text("Double check these against your screenshot above — extracted values aren't always perfect.")
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
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    EarningsScreenshotImportView()
        .modelContainer(for: Shift.self, inMemory: true)
}
