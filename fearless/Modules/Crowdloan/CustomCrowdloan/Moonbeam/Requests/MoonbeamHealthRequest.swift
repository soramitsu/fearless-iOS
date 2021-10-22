import Foundation
import RobinHood

struct MoonbeamHealthRequest: HTTPRequestConfig {
    var path: String {
        "/health"
    }

    var httpMethod: String {
        HttpMethod.get.rawValue
    }

    var headers: [String: String]? {
        nil
    }

    var queryParameters: [URLQueryItem]? {
        nil
    }

    func body() throws -> Data? {
        nil
    }
}
