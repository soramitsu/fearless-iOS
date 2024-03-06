import Foundation
import SSFModels

enum AccountIdVariant {
    case accountId(_ accountId: AccountId)
    case address(_ address: AccountAddress)

    static func build(raw: AccountId, chain: ChainModel) throws -> AccountIdVariant {
        if chain.isReef {
            return try .address(raw.toAddress(using: chain.chainFormat))
        }

        return .accountId(raw)
    }
}
