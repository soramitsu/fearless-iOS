import Foundation
import SSFNetwork

final class NomisRequestSigner: RequestSigner {
    private let clientId: String
    private let apiKey: String

    init(
        clientId: String = NomisApiKeys.nomisClientId,
        apiKey: String = NomisApiKeys.nomisApiKey
    ) {
        self.clientId = clientId.trimmingCharacters(in: .whitespacesAndNewlines)
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // An unconfigured build sends no Nomis headers rather than empty ones; the score then
    // shows its unavailable state.
    func sign(request: inout URLRequest, config _: RequestConfig) throws {
        if !clientId.isEmpty {
            request.setValue(clientId, forHTTPHeaderField: "X-ClientId")
        }
        if !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        }
    }
}
