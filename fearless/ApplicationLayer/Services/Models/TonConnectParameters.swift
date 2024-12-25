import Foundation

struct TonConnectParameters {
    enum Version: String {
        case v2 = "2"
    }

    let version: Version
    let clientId: String
    let requestPayload: TonConnectRequestPayload

    init(version: Version, clientId: String, requestPayload: TonConnectRequestPayload) {
        self.version = version
        self.clientId = clientId
        self.requestPayload = requestPayload
    }
}
