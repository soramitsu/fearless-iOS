import Foundation
import IrohaCrypto

struct AccountCreationRequest {
    let username: String
    let type: Chain
    let derivationPath: String
    let cryptoType: CryptoType
}

struct MetaaccountCreationRequest {
    let username: String
    let derivationPath: String
    let cryptoType: MultiassetCryptoType
}
