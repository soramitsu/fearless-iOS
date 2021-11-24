import Foundation
import RobinHood

struct MoonbeamVerifyRemarkRequest: HTTPRequestConfig {
    let address: String
    let info: MoonbeamVerifyRemarkInfo

    var path: String {
        "/verify-remark"
    }

    var httpMethod: String {
        HttpMethod.post.rawValue
    }

    var headers: [String: String]? {
        [HttpHeaderKey.contentType.rawValue: HttpContentType.json.rawValue]
    }

    var queryParameters: [URLQueryItem]? {
        nil
    }

    func body() throws -> Data? {
        try MoonbeamJSONEncoder().encode(info)
    }
}
