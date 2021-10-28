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
        ["x-api-key": "JbykAAZTUa8MTggXlb4k03yAW9Ur2DFU1T0rm2Th"]
    }

    var queryParameters: [URLQueryItem]? {
        nil
    }

    func body() throws -> Data? {
        nil
    }
}
