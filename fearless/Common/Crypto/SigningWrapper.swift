import Foundation
import IrohaCrypto
import SoraKeystore
import SSFUtils
import SSFModels

enum SigningWrapperError: Error {
    case missingSelectedAccount
    case missingSecretKey
}

final class SigningWrapper: SigningWrapperProtocol {
    let keystore: KeystoreProtocol
    let metaId: String
    let accountId: AccountId?
    let isEthereumBased: Bool
    let cryptoType: CryptoType
    let publicKeyData: Data

    @available(*, deprecated, message: "Use init(keystore:metaId:accountId:cryptoType:) instead")
    init(keystore: KeystoreProtocol, settings _: SettingsManagerProtocol) {
        self.keystore = keystore
        metaId = ""
        accountId = nil
        cryptoType = .sr25519
        isEthereumBased = false
        publicKeyData = Data(repeating: 0, count: 32)
    }

    init(
        keystore: KeystoreProtocol,
        metaId: String,
        accountId: AccountId?,
        isEthereumBased: Bool,
        cryptoType: CryptoType,
        publicKeyData: Data
    ) {
        self.keystore = keystore
        self.metaId = metaId
        self.accountId = accountId
        self.cryptoType = cryptoType
        self.isEthereumBased = isEthereumBased
        self.publicKeyData = publicKeyData
    }

    init(keystore: KeystoreProtocol, metaId: String, accountResponse: ChainAccountResponse) {
        self.keystore = keystore
        self.metaId = metaId
        accountId = accountResponse.isChainAccount ? accountResponse.accountId : nil
        isEthereumBased = accountResponse.isEthereumBased
        cryptoType = accountResponse.cryptoType
        publicKeyData = accountResponse.publicKey
    }

    func sign(_ originalData: Data) throws -> IRSignatureProtocol {
        let tag: String = isEthereumBased ?
            KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: accountId) :
            KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId, accountId: accountId)

        let secretKey = try keystore.fetchKey(for: tag)

        if isEthereumBased {
            return try signEthereumEcdsa(
                originalData,
                secretKey: secretKey
            )
        }

        switch cryptoType {
        case .sr25519:
            return try signSr25519(
                originalData,
                secretKeyData: secretKey,
                publicKeyData: publicKeyData
            )
        case .ed25519:
            return try signEd25519(
                originalData,
                secretKey: secretKey
            )
        case .ecdsa:
            return try signEcdsa(
                originalData,
                secretKey: secretKey
            )
        }
    }
}
