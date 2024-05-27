import Foundation
import SSFModels

struct MetaAccountCreationMetadata {
    let mnemonic: [String]
    let availableCryptoTypes: [CryptoType]
    let defaultCryptoType: CryptoType
}
