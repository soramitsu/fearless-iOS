import Foundation

struct ChainAccountModel: Equatable, Hashable, Codable {
    let chainId: String
    let accountId: Data
    let publicKey: Data
    let cryptoType: UInt8
}
