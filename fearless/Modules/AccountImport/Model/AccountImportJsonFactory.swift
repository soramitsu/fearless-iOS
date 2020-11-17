import Foundation
import FearlessUtils

protocol AccountImportJsonFactoryProtocol {
    func createInfo(from definition: KeystoreDefinition) throws -> AccountImportPreferredInfo
}

final class AccountImportJsonFactory {
    func createInfo(from definition: KeystoreDefinition) throws -> AccountImportPreferredInfo {
        let info = try KeystoreInfoFactory().createInfo(from: definition)

        let chain: Chain?

        if let definitionGenesisHashString = definition.meta?.genesisHash,
           let definitionGenesisHash = try? Data(hexString: definitionGenesisHashString),
           let genesisBasedChain = Chain.allCases
            .first(where: { definitionGenesisHash == (try? Data(hexString: $0.genesisHash)) }) {
            chain = genesisBasedChain
        } else {
            chain = info.addressType?.chain
        }

        return AccountImportPreferredInfo(username: info.meta?.name,
                                          networkType: chain,
                                          cryptoType: CryptoType(info.cryptoType))
    }
}
