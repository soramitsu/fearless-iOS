import Foundation
import RobinHood

struct AcalaContributeRequest: HTTPRequestConfig {
    let contributeInfo: AcalaContributeInfo

    var path: String {
        "/contribute"
    }

    var httpMethod: String {
        HTTPRequestMethod.post.rawValue
    }

    var headers: [String: String]? {
        [HttpHeaderKey.contentType.rawValue: HttpContentType.json.rawValue]
    }

    var queryParameters: [URLQueryItem]? {
        nil
    }

    func body() throws -> Data? {
        try JSONEncoder().encode(contributeInfo)
    }
}
