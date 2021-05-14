import Foundation

struct AccountCreationMetadata {
    let mnemonic: [String]
    let availableCryptoTypes: [CryptoType]
    let defaultCryptoType: CryptoType
}
