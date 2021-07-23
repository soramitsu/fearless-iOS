import UIKit
import FearlessUtils
import SoraFoundation

struct StakingAmountViewModel {
    let title: String
    let balance: BalanceViewModelProtocol
}

struct ValidatorInfoViewModel {
    struct Exposure {
        let nominators: String
        let myNomination: MyNomination?
        let totalStake: BalanceViewModelProtocol
        let estimatedReward: String
    }

    struct MyNomination {
        let isRewarded: Bool
    }

    enum StakingStatus {
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
}
