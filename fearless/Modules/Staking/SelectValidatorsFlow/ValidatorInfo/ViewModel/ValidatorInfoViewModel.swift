import UIKit
import FearlessUtils
import SoraFoundation

enum ValidatorInfoState {
    case empty
    case loading
    case error(String)
    case validatorInfo(ValidatorInfoViewModel)
}

struct StakingAmountViewModel {
    let title: String
    let balance: BalanceViewModelProtocol
}

struct ValidatorInfoViewModel {
    struct ParachainExposure {
        let delegations: String
        let totalStake: BalanceViewModelProtocol
        let estimatedReward: String
        let minimumBond: String
        let selfBonded: String
        let effectiveAmountBonded: String
        let oversubscribed: Bool
    }

    struct Exposure {
        let nominators: String
        let myNomination: MyNomination?
        let totalStake: BalanceViewModelProtocol
        let estimatedReward: String
        let oversubscribed: Bool
    }

    struct MyNomination {
        let isRewarded: Bool
    }

    enum StakingStatus {
        case electedParachain(exposure: ParachainExposure)
        case elected(exposure: Exposure)
        case unelected
    }

    enum IdentityTag {
        case email
        case web
        case riot
        case twitter
    }

    enum IdentityItemValue {
        case text(_ text: String)
        case link(_ url: String, tag: IdentityTag)
    }

    struct IdentityItem {
        let title: String
        let value: IdentityItemValue
    }

    struct Staking {
        let status: StakingStatus
        let slashed: Bool
    }

    let account: AccountInfoViewModel
    let staking: Staking
    let identity: [IdentityItem]?
    let title: String
}
