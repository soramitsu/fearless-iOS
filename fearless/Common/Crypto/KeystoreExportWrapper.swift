import Foundation
import SoraKeystore
import SSFUtils
import IrohaCrypto

protocol KeystoreExportWrapperProtocol {
    func export(
        chainAccount: ChainAccountResponse,
        password: String?,
        address: String,
        metaId: String,
        accountId: AccountId?,
        genesisHash: String?
    ) throws -> Data
}

enum KeystoreExportWrapperError: Error {
    case missingSecretKey
    case unsupportedCryptoType
}

final class KeystoreExportWrapper: KeystoreExportWrapperProtocol {
    let keystore: KeystoreProtocol

    private lazy var jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private lazy var ss58Factory = SS58AddressFactory()

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
    }

    func export(
        chainAccount: ChainAccountResponse,
        password: String?,
        address: String,
        metaId: String,
        accountId: AccountId?,
        genesisHash: String?
    ) throws -> Data {
        let secretKeyTag = chainAccount.isEthereumBased
            ? KeystoreTagV2.ethereumSecretKeyTagForMetaId(metaId, accountId: accountId)
            : KeystoreTagV2.substrateSecretKeyTagForMetaId(metaId, accountId: accountId)

        let secretKey = try keystore.fetchKey(for: secretKeyTag)

        var builder = KeystoreBuilder().with(name: chainAccount.name)

        if let genesisHash = genesisHash, let genesisHashData = try? Data(hexStringSSF: genesisHash) {
            builder = builder.with(genesisHash: genesisHashData.toHex(includePrefix: true))
        }

        guard let cryptoType = SSFUtils.CryptoType(onChainType: chainAccount.cryptoType.rawValue) else {
            throw KeystoreExportWrapperError.unsupportedCryptoType
        }

        let keystoreData = KeystoreData(
            address: address,
            secretKeyData: secretKey,
            publicKeyData: chainAccount.publicKey,
            cryptoType: cryptoType
        )

        let definition = try builder.build(
            from: keystoreData,
            password: password,
            isEthereum: chainAccount.isEthereumBased
        )

        return try jsonEncoder.encode(definition)
    }
}
