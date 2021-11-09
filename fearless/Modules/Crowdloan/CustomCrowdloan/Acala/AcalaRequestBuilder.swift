import Foundation

final class AcalaHTTPRequestBuilder: HTTPRequestBuilder {
    #if F_RELEASE
        static let host: String = "crowdloan.aca-dev.network"
    #else
        static let host: String = "crowdloan.aca-dev.network"
    #endif

    init() {
        super.init(host: AcalaHTTPRequestBuilder.host)
    }
}
