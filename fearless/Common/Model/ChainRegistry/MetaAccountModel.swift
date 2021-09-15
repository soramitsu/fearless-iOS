import Foundation
import RobinHood

struct MetaAccountModel: Equatable {
    let metaId: String
    let name: String
    let substrateAccountId: Data
    let substrateCryptoType: UInt8
    let substratePublicKey: Data
    let ethereumAddress: Data?
    let ethereumPublicKey: Data?
    let chainAccounts: Set<ChainAccountModel>
}

extension MetaAccountModel: Identifiable {
    var identifier: String { metaId }
}
