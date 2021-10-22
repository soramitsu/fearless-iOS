import Foundation

struct AcalaStatementRequest: HTTPRequestConfig {
    var headers: [String: String]? {
        nil
    }

    var queryParameters: [URLQueryItem]? {
        nil
    }

    var body: Data? {
        nil
    }

    var path: String {
        "/statement"
    }

    var httpMethod: String {
        HTTPRequestMethod.get.rawValue
    }
}
