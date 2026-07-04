import SwiftUI

struct VehicleSetupView: View {
    @Bindable var data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var makes: [NHTSAMake] = []
    @State private var models: [NHTSAModel] = []
    @State private var epaOptions: [EPAVehicleOption] = []
    @State private var optionMPGs: [String: EPAMPGResult] = [:]
    @State private var selectedMake: NHTSAMake?
    @State private var selectedModel: NHTSAModel?
    @State private var selectedEPAOption: EPAVehicleOption?
    @State private var makeSearch = ""
    @State private var modelSearch = ""
    @State private var odometerText = ""
    @State private var isLoadingMakes = false
    @State private var isLoadingModels = false
    @State private var isLoadingMPG = false
    @State private var mpgError = false
    @State private var makesError = false
    @State private var modelsError = false

    private let years = Array(stride(from: Calendar.current.component(.year, from: .now), through: 1990, by: -1))

    private var filteredMakes: [NHTSAMake] {
        makeSearch.isEmpty ? makes : makes.filter { $0.name.localizedCaseInsensitiveContains(makeSearch) }
    }
    private var filteredModels: [NHTSAModel] {
        modelSearch.isEmpty ? models : models.filter { $0.name.localizedCaseInsensitiveContains(modelSearch) }
    }
    private var canContinue: Bool {
        !data.makeName.isEmpty && !data.modelName.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    stepHeader(number: "2", title: "Your Vehicle", subtitle: "We use this to calculate your real fuel cost per trip.")
                } header: { EmptyView() }
                .listRowInsets(.init())
                .listRowBackground(Color.clear)

                Section("Year") {
                    Picker("Year", selection: $data.vehicleYear) {
                        ForEach(years, id: \.self) { Text(String($0)).tag($0) }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 120)
                    .onChange(of: data.vehicleYear) { _, _ in resetFromYear() }
                }

                Section("Make") {
                    if isLoadingMakes {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if makesError {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Couldn't load vehicle makes — check your connection.", systemImage: "wifi.slash")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Retry") { Task { await loadMakes() } }
                        }
                    } else if makes.isEmpty {
                        Button("Load Vehicle Makes") { Task { await loadMakes() } }
                    } else if let make = selectedMake {
                        HStack {
                            Text(make.name).fontWeight(.semibold)
                            Spacer()
                            Button("Change") {
                                selectedMake = nil; data.makeName = ""
                                models = []; selectedModel = nil; data.modelName = ""
                                epaOptions = []; data.cityMPG = 0; data.highwayMPG = 0
                            }
                            .font(.caption).foregroundStyle(Color.accentColor)
                        }
                    } else {
                        TextField("Search makes…", text: $makeSearch)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.characters)
                        ForEach(filteredMakes.prefix(80)) { make in
                            Button(make.name) { selectMake(make) }
                                .foregroundStyle(.primary)
                        }
                    }
                }

                if selectedMake != nil {
                    Section("Model") {
                        if isLoadingModels {
                            HStack { Spacer(); ProgressView(); Spacer() }
                        } else if modelsError {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Couldn't load models — check your connection.", systemImage: "wifi.slash")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button("Retry") {
                                    if let make = selectedMake { selectMake(make) }
                                }
                            }
                        } else if let model = selectedModel {
                            HStack {
                                Text(model.name).fontWeight(.semibold)
                                Spacer()
                                Button("Change") {
                                    selectedModel = nil; data.modelName = ""
                                    epaOptions = []; data.cityMPG = 0; data.highwayMPG = 0
                                    selectedEPAOption = nil
                                }
                                .font(.caption).foregroundStyle(Color.accentColor)
                            }
                        } else {
                            TextField("Search models…", text: $modelSearch)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.words)
                            ForEach(filteredModels.prefix(80)) { model in
                                Button(model.name) { selectModel(model) }
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }

                if selectedModel != nil {
                    // Only show drivetrain picker if there are multiple meaningful options
                    if isLoadingMPG {
                        Section {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Fetching MPG from EPA…").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    } else if epaOptions.count > 1 {
                        Section {
                            Picker("Configuration", selection: $selectedEPAOption) {
                                ForEach(epaOptions) { opt in
                                    Text(optionLabel(opt)).tag(Optional(opt))
                                }
                            }
                            .pickerStyle(.inline)
                            .onChange(of: selectedEPAOption) { _, new in
                                if let opt = new, let mpg = optionMPGs[opt.id] {
                                    data.cityMPG = mpg.cityMPG
                                    data.highwayMPG = mpg.highwayMPG
                                }
                            }
                            Text("Note: LE/XLE/XSE trim names aren't in EPA data. Pick by drivetrain and MPG — all trims of the same drivetrain get the same fuel economy rating.")
                                .font(.caption).foregroundStyle(.secondary)
                        } header: { Text("Engine / Drivetrain") }

                    Section("Fuel Economy (MPG)") {
                        LabeledContent("City MPG") {
                            TextField("e.g. 28", value: $data.cityMPG, format: .number)
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                        LabeledContent("Highway MPG") {
                            TextField("e.g. 36", value: $data.highwayMPG, format: .number)
                                .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                        }
                        if data.cityMPG > 0 && data.highwayMPG > 0 {
                            HStack {
                                Text("Combined")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(String(format: "%.0f", (0.55 * data.cityMPG) + (0.45 * data.highwayMPG))) MPG")
                                    .fontWeight(.semibold)
                            }
                        } else if mpgError {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("EPA data unavailable — enter MPG manually, or retry.")
                                    .font(.caption).foregroundStyle(.secondary)
                                Button("Retry") {
                                    if let model = selectedModel { selectModel(model) }
                                }
                            }
                        }
                    }

                    Section("Starting Odometer") {
                        LabeledContent("Current Miles") {
                            TextField("e.g. 42000", text: $odometerText)
                                .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                                .onChange(of: odometerText) { _, v in data.startingOdometer = Double(v) ?? 0 }
                        }
                        Text("Used to track total mileage for depreciation calculations.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back", action: onBack)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Next") { onNext() }
                        .fontWeight(.semibold)
                        .disabled(!canContinue)
                }
            }
        }
        .task { await loadMakes() }
    }

    private func optionLabel(_ opt: EPAVehicleOption) -> String {
        var label = simplifiedLabel(opt.text)
        if let mpg = optionMPGs[opt.id] {
            label += " — \(Int(mpg.cityMPG))/\(Int(mpg.highwayMPG)) mpg"
        }
        return label
    }

    // Converts EPA technical description to plain drivetrain label
    // "Auto-AV, 4 cyl, 2.5 L, Regular, AWD" → "2.5L AWD"
    private func simplifiedLabel(_ epaText: String) -> String {
        let t = epaText.lowercased()
        var parts: [String] = []

        if t.contains("plug-in") || t.contains("phev") { parts.append("Plug-in Hybrid") }
        else if t.contains("hybrid") { parts.append("Hybrid") }
        else if t.contains("electric") || t.contains(" ev") { parts.append("Electric") }

        if t.contains("awd") || t.contains("4wd") || t.contains("4x4") { parts.append("AWD") }
        else if t.contains("fwd") || t.contains("2wd") { parts.append("FWD") }
        else if t.contains("rwd") { parts.append("RWD") }

        // Extract engine displacement e.g. "2.5 L" or "2.5L"
        if let match = epaText.range(of: #"\d+\.\d+"#, options: .regularExpression) {
            parts.insert(String(epaText[match]) + "L", at: 0)
        }

        return parts.isEmpty ? epaText : parts.joined(separator: " ")
    }

    private func loadMakes() async {
        isLoadingMakes = true
        makesError = false
        do {
            makes = try await NHTSAService.shared.fetchMakes()
        } catch {
            makesError = true
        }
        isLoadingMakes = false
    }

    private func selectMake(_ make: NHTSAMake) {
        selectedMake = make
        data.makeName = make.name
        makeSearch = ""
        isLoadingModels = true
        modelsError = false
        Task {
            do {
                models = try await NHTSAService.shared.fetchModels(makeId: make.id)
            } catch {
                modelsError = true
            }
            isLoadingModels = false
        }
    }

    private func selectModel(_ model: NHTSAModel) {
        selectedModel = model
        data.modelName = model.name
        modelSearch = ""
        isLoadingMPG = true
        mpgError = false
        Task {
            do {
                let options = try await EPAService.shared.fetchOptions(
                    year: data.vehicleYear,
                    make: data.makeName,
                    model: model.name
                )
                epaOptions = options

                // Fetch MPG for all options in parallel
                await withTaskGroup(of: (String, EPAMPGResult?).self) { group in
                    for opt in options {
                        group.addTask { (opt.id, try? await EPAService.shared.fetchMPG(vehicleId: opt.id)) }
                    }
                    for await (id, result) in group {
                        if let r = result { optionMPGs[id] = r }
                    }
                }

                // Auto-select first option
                if let first = options.first {
                    selectedEPAOption = first
                    if let mpg = optionMPGs[first.id] {
                        data.cityMPG = mpg.cityMPG
                        data.highwayMPG = mpg.highwayMPG
                    }
                }
            } catch {
                mpgError = true
            }
            isLoadingMPG = false
        }
    }

    private func resetFromYear() {
        selectedMake = nil; data.makeName = ""
        selectedModel = nil; data.modelName = ""
        epaOptions = []; data.cityMPG = 0; data.highwayMPG = 0
        selectedEPAOption = nil; models = []
    }

    private func stepHeader(number: String, title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Step \(number) of 4").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
            Text(title).font(.title2).fontWeight(.bold)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

#Preview {
    VehicleSetupView(data: OnboardingData(), onNext: {}, onBack: {})
}
