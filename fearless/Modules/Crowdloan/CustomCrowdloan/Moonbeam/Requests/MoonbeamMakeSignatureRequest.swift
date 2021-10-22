import Foundation
import RobinHood

struct MoonbeamMakeSignatureRequest: HTTPRequestConfig {
    let address: String
    let info: MoonbeamMakeSignatureInfo

    var path: String {
        "/make-signature"
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
