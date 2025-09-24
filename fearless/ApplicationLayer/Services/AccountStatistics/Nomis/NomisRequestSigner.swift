import Foundation
import SSFNetwork
import FearlessKeys

final class NomisRequestSigner: RequestSigner {
    func sign(request: inout URLRequest, config _: SSFNetwork.RequestConfig) throws {
        let clientId = NomisApiKeys.nomisClientId
        let apiKey = NomisApiKeys.nomisApiKey

        request.setValue(clientId, forHTTPHeaderField: "X-ClientId")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
    }
}
