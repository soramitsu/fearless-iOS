import Foundation
@testable import fearless
import SoraKeystore
import SSFModels

// Test-only shim to preserve older initializer callsites for SigningWrapper
extension SigningWrapper {
    convenience init(
        keystore: KeystoreProtocol,
        metaId: String,
        accountId: AccountId?,
        isEthereumBased: Bool,
        cryptoType: SSFModels.CryptoType,
        publicKeyData: Data
    ) {
        let response = ChainAccountResponse(
            isChainAccount: !isEthereumBased, // heuristic for tests
            accountId: accountId,
            cryptoType: cryptoType
        )
        self.init(keystore: keystore, metaId: metaId, accountResponse: response)
    }
}

