import Foundation
import RobinHood

struct AcalaTransferRequest: HTTPRequestConfig {
    let transferInfo: AcalaTransferInfo

    var path: String {
        "/transfer"
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
        try JSONEncoder().encode(transferInfo)
    }
}
