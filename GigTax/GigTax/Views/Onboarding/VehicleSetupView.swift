import SwiftUI

struct VehicleSetupView: View {
    var data: OnboardingData
    let onNext: () -> Void
    let onBack: () -> Void

    @State private var makes: [NHTSAMake] = []
    @State private var models: [NHTSAModel] = []
    @State private var epaOptions: [EPAVehicleOption] = []
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
                    } else if makes.isEmpty {
                        Button("Load Vehicle Makes") { Task { await loadMakes() } }
                    } else {
                        if let make = selectedMake {
                            HStack {
                                Text(make.name).fontWeight(.semibold)
                                Spacer()
                                Button("Change") { selectedMake = nil; data.makeName = ""; models = []; selectedModel = nil; data.modelName = "" }
                                    .font(.caption).foregroundStyle(.accentColor)
                            }
                        } else {
                            TextField("Search makes…", text: $makeSearch)
                                .textInputAutocapitalization(.words)
                            ForEach(filteredMakes.prefix(50)) { make in
                                Button(make.name) { selectMake(make) }
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }

                if selectedMake != nil {
                    Section("Model") {
                        if isLoadingModels {
                            HStack { Spacer(); ProgressView(); Spacer() }
                        } else if let model = selectedModel {
                            HStack {
                                Text(model.name).fontWeight(.semibold)
                                Spacer()
                                Button("Change") { selectedModel = nil; data.modelName = ""; epaOptions = []; data.cityMPG = 0; data.highwayMPG = 0 }
                                    .font(.caption).foregroundStyle(.accentColor)
                            }
                        } else {
                            TextField("Search models…", text: $modelSearch)
                            ForEach(filteredModels.prefix(50)) { model in
                                Button(model.name) { selectModel(model) }
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                }

                if selectedModel != nil {
                    Section("Trim / Engine") {
                        if isLoadingMPG {
                            HStack { ProgressView(); Text("Fetching MPG from EPA…").font(.caption).foregroundStyle(.secondary) }
                        } else if epaOptions.isEmpty {
                            Text(mpgError ? "Could not load MPG data — enter manually below." : "No EPA data found.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Picker("Trim", selection: $selectedEPAOption) {
                                Text("Select trim…").tag(Optional<EPAVehicleOption>.none)
                                ForEach(epaOptions) { opt in Text(opt.text).tag(Optional(opt)) }
                            }
                            .onChange(of: selectedEPAOption) { _, new in
                                if let opt = new { Task { await loadMPG(option: opt) } }
                            }
                        }
                    }

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
                            Text("Combined: \(String(format: "%.0f", (0.55 * data.cityMPG) + (0.45 * data.highwayMPG))) MPG")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }

                    Section("Starting Odometer") {
                        LabeledContent("Current Miles") {
                            TextField("e.g. 42000", text: $odometerText)
                                .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                                .onChange(of: odometerText) { _, v in data.startingOdometer = Double(v) ?? 0 }
                        }
                        Text("Used to track total vehicle mileage for depreciation calculations.")
                            .font(.caption).foregroundStyle(.secondary)
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

    private func loadMakes() async {
        isLoadingMakes = true
        do { makes = try await NHTSAService.shared.fetchMakes() }
        catch { }
        isLoadingMakes = false
    }

    private func selectMake(_ make: NHTSAMake) {
        selectedMake = make
        data.makeName = make.name
        makeSearch = ""
        isLoadingModels = true
        Task {
            do { models = try await NHTSAService.shared.fetchModels(makeId: make.id) }
            catch { }
            isLoadingModels = false
        }
    }

    private func selectModel(_ model: NHTSAModel) {
        selectedModel = model
        data.modelName = model.name
        modelSearch = ""
        isLoadingMPG = true
        Task {
            do {
                epaOptions = try await EPAService.shared.fetchOptions(year: data.vehicleYear, make: data.makeName, model: model.name)
            } catch {
                mpgError = true
            }
            isLoadingMPG = false
        }
    }

    private func loadMPG(option: EPAVehicleOption) async {
        isLoadingMPG = true
        if let result = try? await EPAService.shared.fetchMPG(vehicleId: option.id) {
            data.cityMPG = result.cityMPG
            data.highwayMPG = result.highwayMPG
        }
        isLoadingMPG = false
    }

    private func resetFromYear() {
        selectedMake = nil; data.makeName = ""
        selectedModel = nil; data.modelName = ""
        epaOptions = []; data.cityMPG = 0; data.highwayMPG = 0
        models = []
    }
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

#Preview {
    VehicleSetupView(data: OnboardingData(), onNext: {}, onBack: {})
}
