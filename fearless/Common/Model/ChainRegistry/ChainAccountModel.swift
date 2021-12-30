import Foundation

struct ChainAccountModel: Equatable, Hashable, Codable {
    let chainId: String
    let accountId: Data
    let publicKey: Data
    let cryptoType: UInt8
}

extension ChainAccountModel {
    func toAddress(addressPrefix: UInt16) -> AccountAddress? {
        try? accountId.toAddress(using: .substrate(addressPrefix))
    }
}
