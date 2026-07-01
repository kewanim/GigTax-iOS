import Foundation

struct EPAVehicleOption: Identifiable, Hashable {
    let id: String      // EPA vehicle ID
    let text: String    // trim description, e.g. "Auto, 4-cyl, 2.5 L"
}

struct EPAMPGResult {
    let vehicleId: String
    let cityMPG: Double
    let highwayMPG: Double
    let combinedMPG: Double
}

// Parses EPA's XML menuItems response: <menuItems><menuItem><text>…</text><value>…</value></menuItem></menuItems>
private final class MenuItemParser: NSObject, XMLParserDelegate {
    var items: [(text: String, value: String)] = []
    private var currentText = ""
    private var currentValue = ""
    private var inText = false
    private var inValue = false

    func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        if element == "text"  { inText = true;  currentText = "" }
        if element == "value" { inValue = true; currentValue = "" }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText  { currentText  += string }
        if inValue { currentValue += string }
    }

    func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?, qualifiedName: String?) {
        if element == "text"     { inText = false }
        if element == "value"    { inValue = false }
        if element == "menuItem" { items.append((currentText, currentValue)) }
    }
}

// Parses a single <vehicle> element to extract city08/highway08/comb08
private final class VehicleParser: NSObject, XMLParserDelegate {
    var city08: Double = 0
    var hwy08: Double  = 0
    var comb08: Double = 0
    private var current = ""
    private var tag = ""

    func parser(_ parser: XMLParser, didStartElement element: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        tag = element
        current = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        current += string
    }

    func parser(_ parser: XMLParser, didEndElement element: String, namespaceURI: String?, qualifiedName: String?) {
        switch element {
        case "city08":     city08 = Double(current.trimmingCharacters(in: .whitespaces)) ?? 0
        case "highway08":  hwy08  = Double(current.trimmingCharacters(in: .whitespaces)) ?? 0
        case "comb08":     comb08 = Double(current.trimmingCharacters(in: .whitespaces)) ?? 0
        default: break
        }
    }
}

actor EPAService {
    static let shared = EPAService()
    private let base = "https://fueleconomy.gov/ws/rest/vehicle"

    func fetchOptions(year: Int, make: String, model: String) async throws -> [EPAVehicleOption] {
        let encodedMake  = make.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? make
        let encodedModel = model.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? model
        let urlStr = "\(base)/menu/options?year=\(year)&make=\(encodedMake)&model=\(encodedModel)"
        guard let url = URL(string: urlStr) else { return [] }

        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = MenuItemParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        xml.parse()
        return parser.items.map { EPAVehicleOption(id: $0.value, text: $0.text) }
    }

    func fetchMPG(vehicleId: String) async throws -> EPAMPGResult? {
        guard let url = URL(string: "\(base)/\(vehicleId)") else { return nil }
        let (data, _) = try await URLSession.shared.data(from: url)
        let parser = VehicleParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        xml.parse()
        guard parser.city08 > 0 else { return nil }
        return EPAMPGResult(vehicleId: vehicleId, cityMPG: parser.city08, highwayMPG: parser.hwy08, combinedMPG: parser.comb08)
    }
}
