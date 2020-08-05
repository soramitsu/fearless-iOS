import Foundation
import IrohaCrypto

struct AccountCreationRequest {
    let username: String
    let type: SNAddressType
    let derivationPath: String
    let cryptoType: CryptoType
}
