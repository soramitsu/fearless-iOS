import Foundation

enum RESTRequestConfiguratorError: Error {
    case badURL
}

final class RESTRequestConfigurator {
    private let baseURL: URL

    init(baseURL: URL) {
        self.baseURL = baseURL
    }
}

extension RESTRequestConfigurator: RequestConfigurator {
    func buildRequest(with config: RequestConfig) throws -> URLRequest {
        var urlComponents = URLComponents()
        urlComponents.scheme = config.baseURL.scheme
        urlComponents.host = config.baseURL.host
        urlComponents.port = config.baseURL.port
        urlComponents.path = config.baseURL.path
        urlComponents.queryItems = config.queryItems

        guard var url = urlComponents.url else {
            throw RESTRequestConfiguratorError.badURL
        }

        if let endpoint = config.endpoint, let urlWithEndpoint = urlComponents.url?.appendingPathComponent(endpoint) {
            url = urlWithEndpoint
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = config.method.rawValue
        urlRequest.httpBody = config.body

        if let timeout = config.timeout {
            urlRequest.timeoutInterval = timeout
        }

        config.headers?.forEach {
            urlRequest.addValue($0.value, forHTTPHeaderField: $0.field)
        }

        #if DEBUG
            if let bodyData = config.body {
                Logger.shared.debug("URL Request: \(urlComponents.url?.absoluteString) ; BODY: \n \(try JSONSerialization.jsonObject(with: bodyData))")
            }
        #endif

        return urlRequest
    }
}
