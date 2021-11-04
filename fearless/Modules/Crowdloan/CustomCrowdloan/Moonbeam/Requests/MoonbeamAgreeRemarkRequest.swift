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
        [HttpHeaderKey.contentType.rawValue: HttpContentType.json.rawValue]
    }

    var queryParameters: [URLQueryItem]? {
        nil
    }

    func body() throws -> Data? {
        try MoonbeamJSONEncoder().encode(info)
    }
}
