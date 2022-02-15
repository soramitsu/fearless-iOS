import Foundation
import SoraKeystore
import FearlessUtils
import IrohaCrypto

protocol KeystoreExportWrapperProtocol {
    func export(chainAccount: ChainAccountResponse, password: String?, address: String) throws -> Data
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

    func export(chainAccount: ChainAccountResponse, password: String?, address: String) throws -> Data {
        guard let secretKey = try keystore.fetchSecretKeyForAddress(address) else {
            throw KeystoreExportWrapperError.missingSecretKey
        }

        let addressType = try ss58Factory.type(fromAddress: address)

        var builder = KeystoreBuilder()
            .with(name: chainAccount.name)

        if let genesisHash = SNAddressType(rawValue: addressType.uint8Value)?.chain.genesisHash,
           let genesisHashData = try? Data(hexString: genesisHash) {
            builder = builder.with(genesisHash: genesisHashData.toHex(includePrefix: true))
        }
        guard let cryptoType = FearlessUtils.CryptoType(onChainType: chainAccount.cryptoType.rawValue) else {
            throw KeystoreExportWrapperError.unsupportedCryptoType
        }
        let keystoreData = KeystoreData(
            address: address,
            secretKeyData: secretKey,
            publicKeyData: chainAccount.publicKey,
            cryptoType: cryptoType
        )

        let definition = try builder.build(from: keystoreData, password: password)

        return try jsonEncoder.encode(definition)
    }
}
