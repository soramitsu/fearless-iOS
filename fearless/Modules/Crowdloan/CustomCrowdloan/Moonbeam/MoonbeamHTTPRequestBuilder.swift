import Foundation

final class MoonbeamHTTPRequestBuilder: HTTPRequestBuilder {
    #if F_RELEASE
        static let host: String = "rpc.polkatrain.moonbeam.network"
    #else
        static let host: String = "rpc.polkatrain.moonbeam.network"
    #endif

    init() {
        super.init(host: MoonbeamHTTPRequestBuilder.host)
    }
}
