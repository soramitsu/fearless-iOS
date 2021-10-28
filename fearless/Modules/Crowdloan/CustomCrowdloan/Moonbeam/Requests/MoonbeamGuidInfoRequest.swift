import Foundation
import RobinHood

struct MoonbeamGuidInfoRequest: HTTPRequestConfig {
    let address: String
    let guid: String

    var path: String {
        "/guid-info"
    }

    var httpMethod: String {
        HttpMethod.get.rawValue
    }

    var headers: [String: String]? {
        ["x-api-key": "JbykAAZTUa8MTggXlb4k03yAW9Ur2DFU1T0rm2Th"]
    }

    var queryParameters: [URLQueryItem]? {
        [URLQueryItem(name: "address", value: address),
         URLQueryItem(name: "guid", value: guid)]
    }

    func body() throws -> Data? {
        nil
    }
}
