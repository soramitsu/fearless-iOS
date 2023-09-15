import Foundation

class RequestConfig {
    let baseURL: URL
    let method: HTTPMethod
    let endpoint: String?
    var queryItems: [URLQueryItem]?
    var headers: [HTTPHeader]?
    var body: Data?

    var requestType: NetworkRequestType = .plain
    var signingType: RequestSigningType = .none
    var networkClientType: NetworkClientType = .plain
    var decoderType: ResponseDecoderType = .codable(jsonDecoder: JSONDecoder())

    init(
        baseURL: URL,
        method: HTTPMethod,
        endpoint: String?,
        queryItems: [URLQueryItem]? = nil,
        headers: [HTTPHeader]?,
        body: Data?
    ) {
        self.baseURL = baseURL
        self.method = method
        self.endpoint = endpoint
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
    }
}
