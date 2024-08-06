import Foundation
import SSFModels

struct MetaAccountImportMetadata {
    let availableSources: [AccountImportSource]
    let defaultSource: AccountImportSource
    let availableCryptoTypes: [CryptoType]
    let defaultCryptoType: CryptoType
}
