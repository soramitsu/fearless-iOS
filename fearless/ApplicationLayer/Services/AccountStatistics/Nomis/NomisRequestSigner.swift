import Foundation
import SSFNetwork

protocol NomisRequestSigningCredentialsSource {
    var nomisClientId: String { get }
    var nomisApiKey: String { get }
}

struct NomisEnvironmentCredentialsSource: NomisRequestSigningCredentialsSource {
    var nomisClientId: String { NomisApiKeys.nomisClientId }
    var nomisApiKey: String { NomisApiKeys.nomisApiKey }
}

final class NomisRequestSigner: RequestSigner {
    private let credentialsSource: NomisRequestSigningCredentialsSource

    init(credentialsSource: NomisRequestSigningCredentialsSource = NomisEnvironmentCredentialsSource()) {
        self.credentialsSource = credentialsSource
    }

    func sign(request: inout URLRequest, config _: RequestConfig) throws {
        let clientId = credentialsSource.nomisClientId
        let apiKey = credentialsSource.nomisApiKey

        request.setValue(clientId, forHTTPHeaderField: "X-ClientId")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
    }
}
