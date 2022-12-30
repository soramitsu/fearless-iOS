import Foundation
import SoraFoundation

enum ValidatorListRelaychainFilterRow: Int, CaseIterable {
    case withoutIdentity
    case slashed
    case oversubscribed
    case clusterLimit

    var titleSubtitleViewModel: LocalizableResource<TitleWithSubtitleViewModel> {
        switch self {
        case .slashed:
            return LocalizableResource { locale in
                TitleWithSubtitleViewModel(
                    title: R.string.localizable
                        .stakingRecommendedHint4(preferredLanguages: locale.rLanguages)
                )
            }

        case .oversubscribed:
            return LocalizableResource { locale in
                TitleWithSubtitleViewModel(
                    title: R.string.localizable
                        .stakingRecommendedHint2(preferredLanguages: locale.rLanguages)
                )
            }

        case .clusterLimit:
            return LocalizableResource { locale in
                TitleWithSubtitleViewModel(
                    title: R.string.localizable
                        .stakingRecommendedHint5(preferredLanguages: locale.rLanguages)
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

enum ValidatorListRelaychainSortRow: Int, CaseIterable {
    case estimatedReward
    case totalStake
    case ownStake

    var sortCriterion: CustomValidatorRelaychainListFilter.CustomValidatorListSort {
        switch self {
        case .estimatedReward:
            return .estimatedReward
        case .ownStake:
            return .ownStake
        case .totalStake:
            return .totalStake
        }
    }
}
