import Foundation
import IrohaCrypto

struct AccountCreationMetadata {
    let mnemonic: [String]
    let availableAddressTypes: [SNAddressType]
    let defaultAddressType: SNAddressType
    let availableCryptoTypes: [CryptoType]
    let defaultCryptoType: CryptoType
}
