import UIKit
import FearlessUtils
import SoraFoundation

protocol ValidatorInfoAccountViewModelProtocol {
    var name: String? { get }
    var address: String { get }
    var icon: UIImage? { get }
}

protocol ImageWithTitleViewModelProtocol {
    var image: UIImage { get }
    var title: String { get }
}

struct ValidatorInfoAccountViewModel: ValidatorInfoAccountViewModelProtocol {
    let name: String?
    let address: String
    let icon: UIImage?
}

struct EmptyStakeViewModel: ImageWithTitleViewModelProtocol {
    let image: UIImage
    let title: String
}

struct StakingAmountViewModel {
    let title: String
    let balance: BalanceViewModelProtocol
}

enum ValidatorInfoViewModel {
    enum StakingRow {
        case totalStake(LocalizableResource<StakingAmountViewModel>)
        case nominators(LocalizableResource<TitleWithSubtitleViewModel>, Bool)
        case estimatedReward(LocalizableResource<TitleWithSubtitleViewModel>)
    }

    enum IdentityRow {
        case legalName(LocalizableResource<TitleWithSubtitleViewModel>)
        case email(LocalizableResource<TitleWithSubtitleViewModel>)
        case web(LocalizableResource<TitleWithSubtitleViewModel>)
        case twitter(LocalizableResource<TitleWithSubtitleViewModel>)
        case riot(LocalizableResource<TitleWithSubtitleViewModel>)
    }

    enum NominationRow {
        case status(LocalizableResource<TitleWithSubtitleViewModel>, ValidatorMyNominationStatus)
        case nominatedAmount(LocalizableResource<StakingAmountViewModel>)
    }

    case account(ValidatorInfoAccountViewModelProtocol)
    case myNomination([NominationRow])
    case emptyStake(LocalizableResource<ImageWithTitleViewModelProtocol>)
    case staking([StakingRow])
    case identity([IdentityRow])
}
