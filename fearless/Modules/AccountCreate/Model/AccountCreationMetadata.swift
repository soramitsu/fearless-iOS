import Foundation
import IrohaCrypto

struct AccountCreationMetadata {
    let mnemonic: [String]
    let availableNetworks: [Chain]
    let defaultNetwork: Chain
    let availableCryptoTypes: [CryptoType]
    let defaultCryptoType: CryptoType
}
