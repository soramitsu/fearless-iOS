import Foundation
import IrohaCrypto

enum RewardDestination<A> {
    case restake
    case payout(account: A)
}

extension RewardDestination: Equatable where A == AccountAddress {
    init(payee: RewardDestinationArg, stashItem: StashItem, chain: Chain) throws {
        switch payee {
        case .staked:
            self = .restake
        case .stash:
            self = .payout(account: stashItem.stash)
        case .controller:
            self = .payout(account: stashItem.controller)
        case let .account(accountId):
            let address = try SS58AddressFactory().addressFromAccountId(
                data: accountId,
                type: chain.addressType
            )
            self = .payout(account: address)
        }
    }
}

extension RewardDestination where A == AccountItem {
    var accountAddress: RewardDestination<AccountAddress> {
        switch self {
        case .restake:
            return .restake
        case let .payout(account):
            return .payout(account: account.address)
        }
    }

    var payoutAccount: AccountItem? {
        switch self {
        case .restake:
            return nil
        case let .payout(account):
            return account
        }
    }
}
