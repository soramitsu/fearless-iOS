import Foundation
import IrohaCrypto

@available(*, deprecated, message: "Use MetaAccountCreationRequest instead")
struct AccountCreationRequest {
    let username: String
    let type: Chain
    let derivationPath: String
    let cryptoType: CryptoType
}

struct MetaAccountCreationRequest {
    let username: String
    let derivationPath: String
    let cryptoType: MultiassetCryptoType
}
