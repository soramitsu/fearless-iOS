import Foundation
import SSFModels

enum AccountIdVariant {
    case accountId(_ accountId: AccountId)
    case address(_ address: AccountAddress)

    static func build(raw: AccountId, chain _: ChainModel) throws -> AccountIdVariant {
        .accountId(raw)
    }
}
