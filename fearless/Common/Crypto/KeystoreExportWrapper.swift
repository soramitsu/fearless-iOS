import Foundation
import SoraKeystore
import FearlessUtils

protocol KeystoreExportWrapperProtocol {
    func export(account: AccountItem, password: String?) throws -> Data
}

enum KeystoreExportWrapperError: Error {
    case missingSecretKey
}

final class KeystoreExportWrapper: KeystoreExportWrapperProtocol {
    let keystore: KeystoreProtocol

    private lazy var jsonEncoder = JSONEncoder()

    init(keystore: KeystoreProtocol) {
        self.keystore = keystore
    }

    func export(account: AccountItem, password: String?) throws -> Data {
        guard let secretKey = try keystore.fetchSecretKeyForAddress(account.address) else {
            throw KeystoreExportWrapperError.missingSecretKey
        }

        let builder = KeystoreBuilder().with(name: account.username)

        let keystoreData = KeystoreData(address: account.address,
                                        secretKeyData: secretKey,
                                        publicKeyData: account.publicKeyData,
                                        cryptoType: account.cryptoType.utilsType)

        let definition = try builder.build(from: keystoreData, password: password)

        return try jsonEncoder.encode(definition)
    }
}
