import Foundation

struct MetaAccountImportMetadata {
    let availableSources: [AccountImportSource]
    let defaultSource: AccountImportSource
    let availableNetworks: [Chain] // TODO: Remove after interactors are done
    let defaultNetwork: Chain // TODO: Remove after interactors are done
    let availableCryptoTypes: [CryptoType]
    let defaultCryptoType: CryptoType
}
