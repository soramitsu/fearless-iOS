import Foundation
import IrohaCrypto

struct MetaAccountCreationRequest {
    let username: String
    let substrateDerivationPath: String
    let substrateCryptoType: CryptoType
    let ethereumDerivationPath: String
}
