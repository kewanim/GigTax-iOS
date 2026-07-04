import Foundation

/// A driver setting this up might have spotty signal between deliveries —
/// every external API call in this app (NHTSA, EPA, EIA) goes through this
/// so none of them can hang on the default 60-second URLSession timeout.
enum NetworkRequest {
    static let timeoutInterval: TimeInterval = 15

    static func data(from url: URL) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.timeoutInterval = timeoutInterval
        return try await URLSession.shared.data(for: request)
    }
}
