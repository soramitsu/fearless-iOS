import Foundation
import IrohaCrypto
import SSFModels

struct MetaAccountCreationRequest {
    let username: String
    let substrateDerivationPath: String
    let substrateCryptoType: CryptoType
    let ethereumDerivationPath: String
}
