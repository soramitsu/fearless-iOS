import Foundation
import SSFModels
import Commons

protocol WalletConnectPayloadSigner {
    func sign(params: AnyCodable) async throws -> AnyCodable
}
