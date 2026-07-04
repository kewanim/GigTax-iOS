import Foundation

struct NHTSAMake: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    enum CodingKeys: String, CodingKey {
        case id = "Make_ID"
        case name = "Make_Name"
    }
}

struct NHTSAModel: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    enum CodingKeys: String, CodingKey {
        case id = "Model_ID"
        case name = "Model_Name"
    }
}

private struct NHTSAResponse<T: Codable>: Codable {
    let results: [T]
    enum CodingKeys: String, CodingKey { case results = "Results" }
}

actor NHTSAService {
    static let shared = NHTSAService()
    private let base = "https://vpic.nhtsa.dot.gov/api/vehicles"

    private var makesCache: [NHTSAMake]?

    func fetchMakes() async throws -> [NHTSAMake] {
        if let cached = makesCache { return cached }
        let url = URL(string: "\(base)/getallmakes?format=json")!
        let (data, _) = try await NetworkRequest.data(from: url)
        let response = try JSONDecoder().decode(NHTSAResponse<NHTSAMake>.self, from: data)
        let sorted = response.results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        makesCache = sorted
        return sorted
    }

    func fetchModels(makeId: Int) async throws -> [NHTSAModel] {
        let url = URL(string: "\(base)/getmodelsformakeid/\(makeId)?format=json")!
        let (data, _) = try await NetworkRequest.data(from: url)
        let response = try JSONDecoder().decode(NHTSAResponse<NHTSAModel>.self, from: data)
        return response.results.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
