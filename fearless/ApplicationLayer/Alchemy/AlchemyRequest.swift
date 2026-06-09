import Foundation
import SSFNetwork

protocol AlchemyAPIKeySource {
    var alchemyApiKey: String { get }
}

struct AlchemyEnvironmentAPIKeySource: AlchemyAPIKeySource {
    var alchemyApiKey: String {
        #if DEBUG
            return ThirdPartyServicesApiKeysDebug.alchemyApiKey
        #else
            return ThirdPartyServicesApiKeys.alchemyApiKey
        #endif
    }
}

final class AlchemyRequest: RequestConfig {
    private enum Constants {
        static let baseURL = URL(string: "https://eth-mainnet.g.alchemy.com/v2")!
        static let httpHeaders = [
            HTTPHeader(field: "accept", value: "application/json"),
            HTTPHeader(field: "content-type", value: "application/json")
        ]
    }

    init(
        body: Data?,
        apiKeySource: AlchemyAPIKeySource = AlchemyEnvironmentAPIKeySource()
    ) {
        super.init(
            baseURL: Constants.baseURL.appendingPathComponent(apiKeySource.alchemyApiKey),
            method: .post,
            endpoint: nil,
            headers: Constants.httpHeaders,
            body: body
        )
    }
}
