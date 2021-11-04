import Foundation

enum HTTPRequestBuilderError: Error {
    case invalidSchemeOrHost
    case invalidURLPath
    case invalidURLParameters
    case invalidBody
}

class HTTPRequestBuilder {
    private var scheme: String?
    private var host: String?
    private var headerBuilder: HTTPHeadersBuilderProtocol?

    init(
        scheme: String = "https",
        host: String,
        headerBuilder: HTTPHeadersBuilderProtocol? = nil
    ) {
        if let url = URL(string: host) {
            self.scheme = url.scheme
            self.host = url.host
        } else {
            self.scheme = scheme
            self.host = host
        }

        self.headerBuilder = headerBuilder
    }
}

extension HTTPRequestBuilder: HTTPRequestBuilderProtocol {
    func buildRequest(with config: HTTPRequestConfig) throws -> URLRequest {
        var urlComponents = URLComponents()
        urlComponents.scheme = scheme
        urlComponents.host = host

        guard urlComponents.url != nil else {
            throw HTTPRequestBuilderError.invalidSchemeOrHost
        }

        urlComponents.path = config.path

        guard urlComponents.url != nil else {
            throw HTTPRequestBuilderError.invalidURLPath
        }

        urlComponents.queryItems = config.queryParameters

        guard let url = urlComponents.url else {
            throw HTTPRequestBuilderError.invalidURLParameters
        }

        var request = URLRequest(url: url)

        request.httpMethod = config.httpMethod

        do {
            request.httpBody = try config.body()
        } catch {
            throw HTTPRequestBuilderError.invalidBody
        }

        var allHeaders: [String: String] = [:]

        if let defaultHeaders = headerBuilder?.buildHeaders() {
            allHeaders = allHeaders.merging(defaultHeaders) { _, new in new }
        }
        if let configHeaders = config.headers {
            allHeaders = allHeaders.merging(configHeaders) { _, new in new }
        }

        request.allHTTPHeaderFields = allHeaders

        return request
    }
}
