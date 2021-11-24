import Foundation

final class MoonbeamHTTPHeadersBuilder: HTTPHeadersBuilderProtocol {
    private static let apiKeyHeaderField: String = "x-api-key"

    private var apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func buildHeaders() -> [String: String]? {
        [MoonbeamHTTPHeadersBuilder.apiKeyHeaderField: apiKey]
    }
}
