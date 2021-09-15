import Foundation

struct ChainAccountModel: Equatable, Hashable {
    let chainId: String
    let accountId: Data
    let publicKey: Data
    let cryptoType: UInt8
}
