import Foundation
// import WalletConnectSwiftV2
import SSFModels
import Commons

protocol WalletConnectPayloadSigner {
    func sign(params: AnyCodable) async throws -> AnyCodable
}
