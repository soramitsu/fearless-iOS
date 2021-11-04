import Foundation
import RobinHood

struct MoonbeamCheckRemarkRequest: HTTPRequestConfig {
    let address: String

    var path: String {
        "/check-remark/\(address)"
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
