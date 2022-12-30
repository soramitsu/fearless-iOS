import Foundation
import SoraFoundation

enum ValidatorListParachainFilterRow: Int, CaseIterable {
    case withoutIdentity
    case oversubscribed

    var titleSubtitleViewModel: LocalizableResource<TitleWithSubtitleViewModel> {
        switch self {
        case .oversubscribed:
            return LocalizableResource { locale in
                TitleWithSubtitleViewModel(
                    title: R.string.localizable
                        .stakingRecommendedFilterMinimumBond(preferredLanguages: locale.rLanguages)
                )
            }
        case .withoutIdentity:
            return LocalizableResource { locale in
                TitleWithSubtitleViewModel(
                    title: R.string.localizable
                        .stakingRecommendedHint3(preferredLanguages: locale.rLanguages),
                    subtitle: R.string.localizable
                        .stakingRecommendedHint3Addition(preferredLanguages: locale.rLanguages)
                )
            }
        }
    }
}

enum ValidatorListParachainSortRow: Int, CaseIterable {
    case estimatedReward
    case effectiveAmountBonded
    case ownStake
    case delegations
    case minimumBond

    var sortCriterion: CustomValidatorParachainListFilter.CustomValidatorParachainListSort {
        switch self {
        case .estimatedReward:
            return .estimatedReward
        case .effectiveAmountBonded:
            return .effectiveAmountBonded
        case .ownStake:
            return .ownStake
        case .delegations:
            return .delegations
        case .minimumBond:
            return .minimumBond
        }
    }
}
