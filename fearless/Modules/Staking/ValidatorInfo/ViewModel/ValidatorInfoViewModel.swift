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
    static let headerHeight: CGFloat = 52.0
    static let rowHeight: CGFloat = 48.0
    static let accountRowHeight: CGFloat = 56.0
    static let emptyStakeRowHeight: CGFloat = 140.0

    enum StakingRow {
        case totalStake(LocalizableResource<TitleWithSubtitleViewModel>)
        case nominators(LocalizableResource<TitleWithSubtitleViewModel>)
        case estimatedReward(LocalizableResource<TitleWithSubtitleViewModel>)
    }

    enum IdentityRow {
        case legalName(LocalizableResource<TitleWithSubtitleViewModel>)
        case email(LocalizableResource<TitleWithSubtitleViewModel>)
        case web(LocalizableResource<TitleWithSubtitleViewModel>)
        case twitter(LocalizableResource<TitleWithSubtitleViewModel>)
        case riot(LocalizableResource<TitleWithSubtitleViewModel>)
    }

    case account(ValidatorInfoAccountViewModelProtocol)
    case emptyStake(LocalizableResource<ImageWithTitleViewModelProtocol>)
    case staking([StakingRow])
    case identity([IdentityRow])
}
