import Foundation
import FearlessKeys

final class AlchemyRequest: RequestConfig {
    private enum Constants {
        #if DEBUG
            static let baseURL = URL(string: "https://eth-mainnet.g.alchemy.com/v2/\(ThirdPartyServicesApiKeysDebug.alchemyApiKey)")!
        #else
            static let baseURL = URL(string: "https://eth-mainnet.g.alchemy.com/v2/\(ThirdPartyServicesApiKeys.alchemyApiKey)")!
        #endif
        static let httpHeaders = [
            HTTPHeader(field: "accept", value: "application/json"),
            HTTPHeader(field: "content-type", value: "application/json")
        ]
    }

    init(body: Data?) {
        super.init(
            baseURL: Constants.baseURL,
            method: .post,
            endpoint: nil,
            headers: Constants.httpHeaders,
            body: body
        )
    }
}
