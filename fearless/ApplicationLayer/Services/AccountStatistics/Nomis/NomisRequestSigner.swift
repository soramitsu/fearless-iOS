import Foundation
import SSFNetwork
#if canImport(FearlessKeys)
    import FearlessKeys
#else
    enum NomisApiKeys {
        static let nomisClientId = ""
        static let nomisApiKey = ""
    }
#endif

final class NomisRequestSigner: RequestSigner {
    func sign(request: inout URLRequest, config _: RequestConfig) throws {
        let clientId = NomisApiKeys.nomisClientId
        let apiKey = NomisApiKeys.nomisApiKey

        request.setValue(clientId, forHTTPHeaderField: "X-ClientId")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
    }
}
