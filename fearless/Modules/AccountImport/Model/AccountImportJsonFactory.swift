import Foundation
import FearlessUtils

protocol AccountImportJsonFactoryProtocol {
    func createInfo(from definition: KeystoreDefinition,
                    supportedNetworks: [Chain]) throws -> AccountImportPreferredInfo
}

final class AccountImportJsonFactory {
    func createInfo(from definition: KeystoreDefinition,
                    supportedNetworks: [Chain]) throws -> AccountImportPreferredInfo {
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

        if let selectedChain = chain, supportedNetworks.contains(selectedChain) {
            return AccountImportPreferredInfo(username: info.meta?.name,
                                              networkType: selectedChain,
                                              cryptoType: CryptoType(info.cryptoType))
        } else {
            return AccountImportPreferredInfo(username: info.meta?.name,
                                              networkType: nil,
                                              cryptoType: CryptoType(info.cryptoType))
        }
    }
}
