import SwiftUI
import SwiftData
import UniformTypeIdentifiers

private enum DuplicatePolicy: String, CaseIterable {
    case skip = "Skip"
    case overwrite = "Overwrite"
}

/// The subset of platforms GigTax knows how to parse a CSV export for.
private enum ImportablePlatform: String, CaseIterable {
    case uber = "Uber"
    case lyft = "Lyft"
    case doorDash = "DoorDash"
    case uberEats = "Uber Eats"

    var platform: Platform {
        switch self {
        case .uber:     return .uber
        case .lyft:     return .lyft
        case .doorDash: return .doorDash
        case .uberEats: return .uberEats
        }
    }

    var columnMap: EarningsCSVColumnMap {
        switch self {
        case .uber:              return EarningsCSVImporter.uber
        case .lyft:               return EarningsCSVImporter.lyft
        case .doorDash, .uberEats: return EarningsCSVImporter.doorDashUberEats
        }
    }
}

struct EarningsImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var existingShifts: [Shift]

    @State private var selectedPlatform = ImportablePlatform.uber
    @State private var isPickingFile = false
    @State private var parsedShifts: [Shift] = []
    @State private var duplicateFlags: [Bool] = []
    @State private var duplicatePolicy = DuplicatePolicy.skip
    @State private var errorMessage: String?
    @State private var isDropTargeted = false

    private var duplicateCount: Int { duplicateFlags.filter { $0 }.count }
    private var totalGross: Double { parsedShifts.reduce(0) { $0 + $1.grossIncome + $1.tips + $1.bonuses } }

    var body: some View {
        NavigationStack {
            Form {
                if parsedShifts.isEmpty {
                    Section("Platform") {
                        Picker("Export from", selection: $selectedPlatform) {
                            ForEach(ImportablePlatform.allCases, id: \.self) { p in
                                Text(p.rawValue).tag(p)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Section {
                        Button {
                            isPickingFile = true
                        } label: {
                            Label("Choose CSV File", systemImage: "doc.badge.plus")
                        }
                    } footer: {
                        Text("Export your earnings history as a CSV from the \(selectedPlatform.rawValue) driver app, then import it here — or drag the file in.")
                    }
                    .listRowBackground(isDropTargeted ? Color.accentColor.opacity(0.12) : nil)
                    .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                        handleDrop(providers)
                    }
                } else {
                    Section("Summary") {
                        LabeledContent("Shifts found", value: "\(parsedShifts.count)")
                        LabeledContent("Total earnings", value: totalGross.formatted(.currency(code: "USD")))
                        if duplicateCount > 0 {
                            LabeledContent("Possible duplicates", value: "\(duplicateCount)")
                        }
                    }

                    if duplicateCount > 0 {
                        Section {
                            Picker("If duplicate", selection: $duplicatePolicy) {
                                ForEach(DuplicatePolicy.allCases, id: \.self) { policy in
                                    Text(policy.rawValue).tag(policy)
                                }
                            }
                            .pickerStyle(.segmented)
                        } footer: {
                            Text("A duplicate is a shift already on the same day, same platform, with the same gross income.")
                        }
                    }

                    Section("Shifts") {
                        ForEach(Array(parsedShifts.enumerated()), id: \.offset) { index, shift in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(shift.date, style: .date)
                                        .font(.subheadline).fontWeight(.semibold)
                                    Text(shift.totalIncome, format: .currency(code: "USD"))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if duplicateFlags[index] {
                                    Text("Duplicate")
                                        .font(.caption2)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(.orange.opacity(0.15))
                                        .foregroundStyle(.orange)
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    Section {
                        Button("Start Over", role: .destructive) { reset() }
                    }
                }
            }
            .navigationTitle("Import Earnings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                if !parsedShifts.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Import") { performImport() }
                            .fontWeight(.semibold)
                    }
                }
            }
            .fileImporter(
                isPresented: $isPickingFile,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                onCompletion: handleFilePicked
            )
            .alert("Couldn't Import File", isPresented: .constant(errorMessage != nil), actions: {
                Button("OK") { errorMessage = nil }
            }, message: {
                Text(errorMessage ?? "")
            })
        }
    }

    private func handleFilePicked(_ result: Result<URL, Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let url):
            parse(fileAt: url)
        }
    }

    private func parse(fileAt url: URL) {
        let didAccess = url.startAccessingSecurityScopedResource()
        defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

        do {
            let data = try Data(contentsOf: url)
            guard let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
                errorMessage = "That file doesn't look like a text CSV."
                return
            }
            let shifts = try EarningsCSVImporter.parse(
                csv: text,
                platform: selectedPlatform.platform,
                columnMap: selectedPlatform.columnMap
            )
            parsedShifts = shifts
            duplicateFlags = shifts.map { isDuplicate($0) }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }) else {
            return false
        }
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, error in
            guard error == nil else {
                DispatchQueue.main.async { errorMessage = error?.localizedDescription ?? "Couldn't read the dropped file." }
                return
            }
            let url: URL?
            if let data = item as? Data {
                url = URL(dataRepresentation: data, relativeTo: nil)
            } else {
                url = item as? URL
            }
            guard let fileURL = url else { return }
            DispatchQueue.main.async { parse(fileAt: fileURL) }
        }
        return true
    }

    private func isDuplicate(_ shift: Shift) -> Bool {
        matchingExistingShift(for: shift) != nil
    }

    private func matchingExistingShift(for shift: Shift) -> Shift? {
        let calendar = Calendar.current
        return existingShifts.first {
            $0.platform == shift.platform
                && calendar.isDate($0.date, inSameDayAs: shift.date)
                && abs($0.grossIncome - shift.grossIncome) < 0.01
        }
    }

    private func performImport() {
        for (index, shift) in parsedShifts.enumerated() {
            if duplicateFlags[index] {
                switch duplicatePolicy {
                case .skip:
                    continue
                case .overwrite:
                    if let existing = matchingExistingShift(for: shift) {
                        existing.tips = shift.tips
                        existing.bonuses = shift.bonuses
                        existing.importedMiles = shift.importedMiles
                        existing.importSource = shift.importSource
                        continue
                    }
                }
            }
            modelContext.insert(shift)
        }
        try? modelContext.save()
        dismiss()
    }

    private func reset() {
        parsedShifts = []
        duplicateFlags = []
        errorMessage = nil
    }
}

#Preview {
    EarningsImportView()
        .modelContainer(for: Shift.self, inMemory: true)
}
