import Foundation

protocol ValidatorListFilterViewModelFactoryProtocol {
    func createViewModel(
        from filter: CustomValidatorListFilter,
        initialFilter: CustomValidatorListFilter,
        token: String,
        locale: Locale
    ) -> ValidatorListFilterViewModel
}

struct ValidatorListFilterViewModelFactory {
    private func createFilterViewModelSection(
        from filter: CustomValidatorListFilter,
        locale: Locale
    ) -> ValidatorListFilterViewModelSection {
        let cellViewModels: [SelectableViewModel<TitleWithSubtitleViewModel>] =
            ValidatorListFilterRow.allCases.map { row in
                switch row {
                case .withoutIdentity:
                    return SelectableViewModel(
                        underlyingViewModel: row.titleSubtitleViewModel.value(for: locale),
                        selectable: !filter.allowsNoIdentity
                    )

                case .slashed:
                    return SelectableViewModel(
                        underlyingViewModel: row.titleSubtitleViewModel.value(for: locale),
                        selectable: !filter.allowsSlashed
                    )

                case .oversubscribed:
                    return SelectableViewModel(
                        underlyingViewModel: row.titleSubtitleViewModel.value(for: locale),
                        selectable: !filter.allowsOversubscribed
                    )

                case .clusterLimit:
                    let allowsUnlimitedClusters = filter.allowsClusters == .unlimited
                    return SelectableViewModel(
                        underlyingViewModel: row.titleSubtitleViewModel.value(for: locale),
                        selectable: !allowsUnlimitedClusters
                    )
                }
            }

        let title = R.string.localizable.walletFiltersHeader(
            preferredLanguages: locale.rLanguages
        )

        return ValidatorListFilterViewModelSection(
            title: title,
            cellViewModels: cellViewModels
        )
    }

    private func createSortViewModelSection(
        from filter: CustomValidatorListFilter,
        token: String,
        locale: Locale
    ) -> ValidatorListFilterViewModelSection {
        let cellViewModels: [SelectableViewModel<TitleWithSubtitleViewModel>] =
            ValidatorListSortRow.allCases.map { row in
                switch row {
                case .estimatedReward:
                    let titleSubtitleViewModel = TitleWithSubtitleViewModel(
                        title: R.string.localizable
                            .stakingValidatorApyPercent(preferredLanguages: locale.rLanguages)
                    )

                    return SelectableViewModel(
                        underlyingViewModel: titleSubtitleViewModel,
                        selectable: filter.sortedBy == .estimatedReward
                    )

                case .ownStake:
                    let titleSubtitleViewModel = TitleWithSubtitleViewModel(
                        title: R.string.localizable
                            .stakingFilterTitleOwnStakeToken(
                                token,
                                preferredLanguages: locale.rLanguages
                            )
                    )

                    return SelectableViewModel(
                        underlyingViewModel: titleSubtitleViewModel,
                        selectable: filter.sortedBy == .ownStake
                    )

                case .totalStake:
                    let titleSubtitleViewModel = TitleWithSubtitleViewModel(
                        title: R.string.localizable
                            .stakingValidatorTotalStakeToken(
                                token,
                                preferredLanguages: locale.rLanguages
                            )
                    )

                    return SelectableViewModel(
                        underlyingViewModel: titleSubtitleViewModel,
                        selectable: filter.sortedBy == .totalStake
                    )
                }
            }

        let sectionTitle = R.string.localizable.commonFilterSortHeader(
            preferredLanguages: locale.rLanguages
        )

        return ValidatorListFilterViewModelSection(
            title: sectionTitle,
            cellViewModels: cellViewModels
        )
    }
}

extension ValidatorListFilterViewModelFactory: ValidatorListFilterViewModelFactoryProtocol {
    func createViewModel(
        from filter: CustomValidatorListFilter,
        initialFilter: CustomValidatorListFilter,
        token: String,
        locale: Locale
    ) -> ValidatorListFilterViewModel {
        ValidatorListFilterViewModel(
            filterModel: createFilterViewModelSection(from: filter, locale: locale),
            sortModel: createSortViewModelSection(from: filter, token: token, locale: locale),
            canApply: filter != initialFilter,
            canReset: filter != CustomValidatorListFilter.recommendedFilter()
        )
    }
}
