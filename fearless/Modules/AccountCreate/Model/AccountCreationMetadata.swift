import Foundation

@available(*, deprecated, message: "Use MetaAccountCreationMetadata instead")
struct AccountCreationMetadata {
    let mnemonic: [String]
    let availableCryptoTypes: [CryptoType]
    let defaultCryptoType: CryptoType
}

struct MetaAccountCreationMetadata {
    let mnemonic: [String]
    let availableCryptoTypes: [MultiassetCryptoType]
    let defaultCryptoType: MultiassetCryptoType
}
