import Foundation
import IrohaCrypto

enum RewardDestination<A> {
    case restake
    case payout(account: A)
}

extension RewardDestination: Equatable where A == AccountAddress {
    init(payee: RewardDestinationArg, stashItem: StashItem, chainFormat: ChainFormat) throws {
        switch payee {
        case .staked:
            self = .restake
        case .stash:
            self = .payout(account: stashItem.stash)
        case .controller:
            self = .payout(account: stashItem.controller)
        case let .account(accountId):
            let address = try accountId.toAddress(using: chainFormat)
            self = .payout(account: address)
        }
    }

    @available(*, deprecated, message: "Use init(payee:stashItem:chainFormat:) instead")
    init(payee: RewardDestinationArg, stashItem: StashItem, chain _: Chain) throws {
        switch payee {
        case .staked:
            self = .restake
        case .stash:
            self = .payout(account: stashItem.stash)
        case .controller:
            self = .payout(account: stashItem.controller)
        case let .account(accountId):
            let address = try accountId.toAddress(using: ChainFormat.substrate(42))
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
