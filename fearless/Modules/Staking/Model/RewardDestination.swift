import Foundation
import IrohaCrypto

enum RewardDestination {
    case restake
    case payout(address: String)
}

extension RewardDestination {
    init(payee: RewardDestinationArg, stashItem: StashItem, chain: Chain) throws {
        switch payee {
        case .staked:
            self = .restake
        case .stash:
            self = .payout(address: stashItem.stash)
        case .controller:
            self = .payout(address: stashItem.controller)
        case .account(let accountId):
            let address = try SS58AddressFactory().addressFromAccountId(data: accountId,
                                                                        type: chain.addressType)
            self = .payout(address: address)
        }
    }
}
