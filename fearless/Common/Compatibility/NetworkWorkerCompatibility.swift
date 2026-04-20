import Foundation
import SSFNetwork
import RobinHood

// Recreate the legacy request-building surface expected by app code on top of
// the current SSFNetwork request model.

public struct HTTPHeader {
    public let field: String
    public let value: String

    public init(field: String, value: String) {
        self.field = field
        self.value = value
    }
}

public protocol RequestSigner {
    func sign(request: inout URLRequest, config: RequestConfig) throws
}

public enum RequestSigningType {
    case none
    case custom(signer: RequestSigner)
}

public enum RequestDecoderType {
    case codable(jsonDecoder: JSONDecoder)
}

open class RequestConfig {
    public let baseURL: URL
    public let method: HttpMethod
    public let endpoint: String?
    public let queryItems: [URLQueryItem]?
    public let headers: [HTTPHeader]
    public let body: Data?

    public var signingType: RequestSigningType = .none
    public var decoderType: RequestDecoderType = .codable(jsonDecoder: JSONDecoder())

    public init(
        baseURL: URL,
        method: HttpMethod,
        endpoint: String?,
        queryItems: [URLQueryItem]? = nil,
        headers: [HTTPHeader]?,
        body: Data?
    ) {
        self.baseURL = baseURL
        self.method = method
        self.endpoint = endpoint
        self.queryItems = queryItems
        self.headers = headers ?? []
        self.body = body
    }
}

public final class NetworkWorkerDefault {
    private let session: URLSession
    private let decoder: JSONDecoder

    public init(
        session: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.session = session
        self.decoder = decoder
    }

    public func performRequest<T: Decodable>(
        with config: RequestConfig
    ) async throws -> T {
        var request = try buildRequest(from: config)

        if case let .custom(signer) = config.signingType {
            try signer.sign(request: &request, config: config)
        }

        let (data, _) = try await session.data(for: request)

        if T.self == Data.self, let raw = data as? T {
            return raw
        }

        let effectiveDecoder: JSONDecoder
        switch config.decoderType {
        case let .codable(jsonDecoder):
            effectiveDecoder = jsonDecoder
        }

        return try effectiveDecoder.decode(T.self, from: data)
    }

    private func buildRequest(from config: RequestConfig) throws -> URLRequest {
        var url: URL = {
            guard let endpoint = config.endpoint else {
                return config.baseURL
            }

            return config.baseURL.appendingPathComponent(endpoint)
        }()

        if let queryItems = config.queryItems,
           var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            components.queryItems = queryItems
            if let urlWithQuery = components.url {
                url = urlWithQuery
            }
        }

        var request = URLRequest(url: url)
        request.httpMethod = config.method.rawValue
        request.httpBody = config.body

        config.headers.forEach { header in
            request.setValue(header.value, forHTTPHeaderField: header.field)
        }

        return request
    }
}

// Lightweight cache control placeholders to satisfy existing interfaces.
public enum CachedNetworkRequestTrigger {
    case none
    case onAll
}

public struct CachedNetworkResponse<T: Decodable> {
    public let data: T
    public init(data: T) { self.data = data }
}

public extension NetworkWorkerDefault {
    func performRequest<T: Decodable>(
        with config: RequestConfig,
        withCacheOptions _: CachedNetworkRequestTrigger
    ) async throws -> AsyncThrowingStream<CachedNetworkResponse<T>, Error> {
        let value: T = try await performRequest(with: config)
        return AsyncThrowingStream { continuation in
            continuation.yield(CachedNetworkResponse(data: value))
            continuation.finish()
        }
    }
}
