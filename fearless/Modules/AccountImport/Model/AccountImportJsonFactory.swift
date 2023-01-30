import Foundation
import FearlessUtils

protocol AccountImportJsonFactoryProtocol {
    func createInfo(from definition: KeystoreDefinition) throws -> MetaAccountImportPreferredInfo
}

final class AccountImportJsonFactory {
    func createInfo(from definition: KeystoreDefinition) throws -> MetaAccountImportPreferredInfo {
        let info = try KeystoreInfoFactory().createInfo(from: definition)

        // TODO: Check with Ethereum data
        return MetaAccountImportPreferredInfo(
            username: info.meta?.name,
            cryptoType: CryptoType(info.cryptoType),
            networkTypeConfirmed: false
        )
    }
}
