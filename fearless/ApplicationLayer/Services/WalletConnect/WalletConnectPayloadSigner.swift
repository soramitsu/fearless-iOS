import Foundation
import SSFModels
import FearlessWalletConnect

protocol WalletConnectPayloadSigner {
    func sign() async throws -> AnyCodable
}
