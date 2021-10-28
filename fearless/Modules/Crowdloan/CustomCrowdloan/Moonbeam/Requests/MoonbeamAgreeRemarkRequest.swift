import Foundation
import RobinHood

struct MoonbeamAgreeRemarkRequest: HTTPRequestConfig {
    let info: MoonbeamAgreeRemarkInfo

    var path: String {
        "/agree-remark"
    }

    var httpMethod: String {
        HttpMethod.post.rawValue
    }

    var headers: [String: String]? {
        [HttpHeaderKey.contentType.rawValue: HttpContentType.json.rawValue,
         "x-api-key": "JbykAAZTUa8MTggXlb4k03yAW9Ur2DFU1T0rm2Th"]
    }

    var queryParameters: [URLQueryItem]? {
        nil
    }

    func body() throws -> Data? {
        try MoonbeamJSONEncoder().encode(info)
    }
}
