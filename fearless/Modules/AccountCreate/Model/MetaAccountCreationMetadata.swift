import Foundation

struct MetaAccountCreationMetadata {
    let mnemonic: [String]
    let availableCryptoTypes: [CryptoType]
    let defaultCryptoType: CryptoType
}
