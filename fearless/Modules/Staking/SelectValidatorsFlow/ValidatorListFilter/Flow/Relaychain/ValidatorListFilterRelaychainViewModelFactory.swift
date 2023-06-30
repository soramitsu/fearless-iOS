import Foundation

final class ValidatorListFilterRelaychainViewModelFactory {
    private func createFilterViewModelSection(
        from filter: CustomValidatorRelaychainListFilter,
        locale: Locale
    ) -> ValidatorListFilterViewModelSection {
        let cellViewModels: [SelectableViewModel<TitleWithSubtitleViewModel>] =
            ValidatorListRelaychainFilterRow.allCases.map { row in
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

        let title = R.string.localizable.commonShow(
            preferredLanguages: locale.rLanguages
        )

        return ValidatorListFilterViewModelSection(
            title: title,
            cellViewModels: cellViewModels
        )
    }

    private func createSortViewModelSection(
        from filter: CustomValidatorRelaychainListFilter,
        token: String,
        locale: Locale
    ) -> ValidatorListFilterViewModelSection {
        let cellViewModels: [SelectableViewModel<TitleWithSubtitleViewModel>] =
            ValidatorListRelaychainSortRow.allCases.map { row in
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

extension ValidatorListFilterRelaychainViewModelFactory: ValidatorListFilterViewModelFactoryProtocol {
    func buildViewModel(viewModelState: ValidatorListFilterViewModelState, token: String, locale: Locale) -> ValidatorListFilterViewModel? {
        guard let relaychainViewModelState = viewModelState as? ValidatorListFilterRelaychainViewModelState else {
            return nil
        }

        return ValidatorListFilterViewModel(
            filterModel: createFilterViewModelSection(from: relaychainViewModelState.currentFilter, locale: locale),
            sortModel: createSortViewModelSection(from: relaychainViewModelState.currentFilter, token: token, locale: locale),
            canApply: relaychainViewModelState.currentFilter != relaychainViewModelState.initialFilter,
            canReset: relaychainViewModelState.currentFilter != CustomValidatorRelaychainListFilter.recommendedFilter()
        )
    }
}
