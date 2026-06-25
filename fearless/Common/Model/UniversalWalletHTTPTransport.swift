import Foundation

protocol UniversalWalletHTTPTransport {
    func perform(_ request: URLRequest) async throws -> Data
}

enum UniversalWalletHTTPTransportError: Error, Equatable {
    case invalidResponse
    case httpStatusCode(Int, Data)
}

final class URLSessionUniversalWalletHTTPTransport: UniversalWalletHTTPTransport {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func perform(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UniversalWalletHTTPTransportError.invalidResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw UniversalWalletHTTPTransportError.httpStatusCode(httpResponse.statusCode, data)
        }

        return data
    }
}
