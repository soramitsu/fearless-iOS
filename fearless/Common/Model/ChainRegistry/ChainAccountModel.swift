import Foundation
import SSFModels

// struct ChainAccountModel: Equatable, Hashable, Codable {
//    let chainId: String
//    let accountId: AccountId
//    let publicKey: Data
//    let cryptoType: UInt8
//    let ethereumBased: Bool
// }

extension ChainAccountModel {
    func toAddress(addressPrefix: UInt16) -> AccountAddress? {
        try? accountId.toAddress(using: .substrate(addressPrefix))
    }
}
