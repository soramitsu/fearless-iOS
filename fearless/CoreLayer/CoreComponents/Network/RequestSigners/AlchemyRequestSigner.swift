import Foundation

final class AlchemyRequestSigner {
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }
}

extension AlchemyRequestSigner: RequestSigner {
    func sign(request: inout URLRequest, config: RequestConfig) throws {
        guard
            var urlString = request.url?.absoluteString,
            let baseUrlBound = urlString.range(of: config.baseURL.absoluteString)?.upperBound
        else {
            throw RequestSignerError.badURL
        }

        urlString.insert(contentsOf: apiKey, at: baseUrlBound)
        request.url = URL(string: urlString)
    }
}
