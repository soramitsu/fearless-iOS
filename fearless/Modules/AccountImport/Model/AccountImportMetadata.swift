import Foundation
import IrohaCrypto

struct AccountImportMetadata {
    let availableSources: [AccountImportSource]
    let defaultSource: AccountImportSource
    let availableAddressTypes: [SNAddressType]
    let defaultAddressType: SNAddressType
    let availableCryptoTypes: [CryptoType]
    let defaultCryptoType: CryptoType
}
