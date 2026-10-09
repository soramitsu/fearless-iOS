import Foundation

protocol UniversalWalletHTTPTransport {
    func perform(_ request: URLRequest) async throws -> Data
    func performResponse(_ request: URLRequest) async throws -> UniversalWalletHTTPResponse
}

struct UniversalWalletHTTPResponse {
    let data: Data
    let headers: [AnyHashable: Any]

    func header(_ name: String) -> String? {
        headers.first { key, _ in
            String(describing: key).caseInsensitiveCompare(name) == .orderedSame
        }.map { String(describing: $0.value) }
    }
}

extension UniversalWalletHTTPTransport {
    func performResponse(_ request: URLRequest) async throws -> UniversalWalletHTTPResponse {
        UniversalWalletHTTPResponse(data: try await perform(request), headers: [:])
    }
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
        try await performResponse(request).data
    }

    func performResponse(_ request: URLRequest) async throws -> UniversalWalletHTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UniversalWalletHTTPTransportError.invalidResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw UniversalWalletHTTPTransportError.httpStatusCode(httpResponse.statusCode, data)
        }

        return UniversalWalletHTTPResponse(data: data, headers: httpResponse.allHeaderFields)
    }
}
