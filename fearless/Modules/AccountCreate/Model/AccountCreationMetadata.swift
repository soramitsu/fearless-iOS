import Foundation
import IrohaCrypto

struct AccountCreationMetadata {
    let mnemonic: [String]
    let availableAccountTypes: [SNAddressType]
    let defaultAccountType: SNAddressType
    let availableCryptoTypes: [CryptoType]
    let defaultCryptoType: CryptoType
}
