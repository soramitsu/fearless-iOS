import Foundation

@available(*, deprecated, message: "Use MetaAccountImportMetadata instead")
struct AccountImportMetadata {
    let availableSources: [AccountImportSource]
    let defaultSource: AccountImportSource
    let availableNetworks: [Chain]
    let defaultNetwork: Chain
    let availableCryptoTypes: [CryptoType]
    let defaultCryptoType: CryptoType
}

// TODO: Rename after refactoring
struct MetaAccountImportMetadata {
    let availableSources: [AccountImportSource]
    let defaultSource: AccountImportSource
    let availableNetworks: [Chain] // TODO: Remove after interactors are done
    let defaultNetwork: Chain // TODO: Remove after interactors are done
    let availableCryptoTypes: [MultiassetCryptoType]
    let defaultCryptoType: MultiassetCryptoType
}
