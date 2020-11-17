import Foundation
import SoraKeystore
import FearlessUtils
import IrohaCrypto

protocol KeystoreExportWrapperProtocol {
    func export(account: AccountItem, password: String?) throws -> Data
}

enum KeystoreExportWrapperError: Error {
    case missingSecretKey
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

    func export(account: AccountItem, password: String?) throws -> Data {
        guard let secretKey = try keystore.fetchSecretKeyForAddress(account.address) else {
            throw KeystoreExportWrapperError.missingSecretKey
        }

        let addressType = try ss58Factory.type(fromAddress: account.address)

        var builder = KeystoreBuilder()
            .with(name: account.username)

        if let genesisHash = SNAddressType(rawValue: addressType.uint8Value)?.chain.genesisHash,
           let genesisHashData = try? Data(hexString: genesisHash) {
            builder = builder.with(genesisHash: genesisHashData.toHex(includePrefix: true))
        }

        let keystoreData = KeystoreData(address: account.address,
                                        secretKeyData: secretKey,
                                        publicKeyData: account.publicKeyData,
                                        cryptoType: account.cryptoType.utilsType)

        let definition = try builder.build(from: keystoreData, password: password)

        return try jsonEncoder.encode(definition)
    }
}
