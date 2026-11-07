import Foundation
import SSFModels
import FearlessWalletConnect

protocol WalletConnectPayloadSigner {
    func sign(params: AnyCodable) async throws -> AnyCodable
}
