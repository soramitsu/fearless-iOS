import Foundation

final class AcalaHTTPRequestBuilder: HTTPRequestBuilder {
    #if F_RELEASE
        static let host: String = "https://crowdloan.aca-api.network"
    #else
        static let host: String = "https://crowdloan.aca-dev.network"
    #endif

    init() {
        super.init(host: AcalaHTTPRequestBuilder.host)
    }
}
