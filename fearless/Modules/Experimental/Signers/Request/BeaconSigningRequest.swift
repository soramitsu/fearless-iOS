import Foundation
import BeaconSDK

final class BeaconSigningRequest: SignerOperationRequestProtocol {
    let request: Beacon.Request.SignPayload
    let client: Beacon.Client
    let signingPayload: Data

    init(client: Beacon.Client, request: Beacon.Request.SignPayload) throws {
        self.request = request
        self.client = client
        signingPayload = try Data(hexString: request.payload)
    }

    func submit(signature: Data, completion closure: @escaping (Result<Void, Error>) -> Void) {
        let response = Beacon.Response.SignPayload(from: request, signature: signature.toHex(includePrefix: true))
        client.respond(with: .signPayload(response)) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    closure(.success(()))
                case let .failure(error):
                    closure(.failure(error))
                }
            }
        }
    }
}
