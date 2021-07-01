import SoraFoundation

struct ValidatorListFilterViewModel {
    let filterModel: ValidatorListFilterViewModelSection
    let sortModel: ValidatorListFilterViewModelSection
    let canApply: Bool
    let canReset: Bool
}

struct ValidatorListFilterViewModelSection {
    let title: String
    let cellViewModels: [SelectableViewModel<TitleWithSubtitleViewModel>]
}

struct ValidatorListFilterCellViewModel {
    let title: String
    let subtitle: String?
    let isSelected: Bool
}

enum ValidatorListFilterRow: Int, CaseIterable {
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

enum ValidatorListSortRow: Int, CaseIterable {
    case estimatedReward
    case totalStake
    case ownStake

    var sortCriterion: CustomValidatorListFilter.CustomValidatorListSort {
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
