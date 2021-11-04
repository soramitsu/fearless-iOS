import Foundation

enum HTTPRequestMethod: String {
    case get = "GET"
    case post = "POST"
    case delete = "DELETE"
    case put = "PUT"
    case patch = "PATCH"
}

protocol HTTPRequestConfig {
    var path: String { get }
    var httpMethod: String { get }
    var headers: [String: String]? { get }
    var queryParameters: [URLQueryItem]? { get }

    func body() throws -> Data?
}
