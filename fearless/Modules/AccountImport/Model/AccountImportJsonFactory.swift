import Foundation
import SSFUtils
import SSFModels

protocol AccountImportJsonFactoryProtocol {
    func createInfo(from definition: KeystoreDefinition) throws -> MetaAccountImportPreferredInfo
}

final class AccountImportJsonFactory {
    func createInfo(from definition: KeystoreDefinition) throws -> MetaAccountImportPreferredInfo {
        let info = try KeystoreInfoFactory().createInfo(from: definition)

        return MetaAccountImportPreferredInfo(
            username: info.meta?.name,
            cryptoType: info.cryptoType,
            isEthereum: info.isEthereum
        )
    }
}
