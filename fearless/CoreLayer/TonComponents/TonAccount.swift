import Foundation
import TonAPI
import TonSwift

struct TonAccount {
    let address: TonSwift.Address
    let balance: Int64
    let status: String
    let name: String?
    let icon: String?
    let isSuspended: Bool?
    let isWallet: Bool

    init(account: Components.Schemas.Account) throws {
        address = try TonSwift.Address.parse(account.address)
        balance = account.balance
        status = account.status
        name = account.name
        icon = account.icon
        isSuspended = account.is_suspended
        isWallet = account.is_wallet
    }
}
