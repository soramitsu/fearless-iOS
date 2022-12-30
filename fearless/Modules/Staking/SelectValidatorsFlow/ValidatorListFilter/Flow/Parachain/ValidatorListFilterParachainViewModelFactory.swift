import Foundation

final class ValidatorListFilterParachainViewModelFactory {
    private func createFilterViewModelSection(
        from _: CustomValidatorParachainListFilter,
        locale _: Locale
    ) -> ValidatorListFilterViewModelSection? {
        nil
    }

    private func createSortViewModelSection(
        from filter: CustomValidatorParachainListFilter,
        token: String,
        locale: Locale
    ) -> ValidatorListFilterViewModelSection {
        let cellViewModels: [SelectableViewModel<TitleWithSubtitleViewModel>] =
            ValidatorListParachainSortRow.allCases.map { row in
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
                            .parachainStakingFiltersCollatorOwnStake(
                                token,
                                preferredLanguages: locale.rLanguages
                            )
                    )

                    return SelectableViewModel(
                        underlyingViewModel: titleSubtitleViewModel,
                        selectable: filter.sortedBy == .ownStake
                    )

                case .effectiveAmountBonded:
                    let titleSubtitleViewModel = TitleWithSubtitleViewModel(
                        title: R.string.localizable
                            .parachainStakingFiltersEffectiveAmountBonded(
                                token,
                                preferredLanguages: locale.rLanguages
                            )
                    )

                    return SelectableViewModel(
                        underlyingViewModel: titleSubtitleViewModel,
                        selectable: filter.sortedBy == .effectiveAmountBonded
                    )
                case .delegations:
                    let titleSubtitleViewModel = TitleWithSubtitleViewModel(
                        title: R.string.localizable
                            .parachainStakingFiltersDelegations(
                                preferredLanguages: locale.rLanguages
                            )
                    )

                    return SelectableViewModel(
                        underlyingViewModel: titleSubtitleViewModel,
                        selectable: filter.sortedBy == .delegations
                    )

                case .minimumBond:
                    let titleSubtitleViewModel = TitleWithSubtitleViewModel(
                        title: R.string.localizable
                            .parachainStakingFiltersMinimumBond(
                                preferredLanguages: locale.rLanguages
                            )
                    )

                    return SelectableViewModel(
                        underlyingViewModel: titleSubtitleViewModel,
                        selectable: filter.sortedBy == .minimumBond
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

extension ValidatorListFilterParachainViewModelFactory: ValidatorListFilterViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: ValidatorListFilterViewModelState,
        token: String,
        locale: Locale
    ) -> ValidatorListFilterViewModel? {
        guard let parachainViewModelState = viewModelState as? ValidatorListFilterParachainViewModelState else {
            return nil
        }

        return ValidatorListFilterViewModel(
            filterModel: createFilterViewModelSection(
                from: parachainViewModelState.currentFilter,
                locale: locale
            ),
            sortModel: createSortViewModelSection(
                from: parachainViewModelState.currentFilter,
                token: token,
                locale: locale
            ),
            canApply: parachainViewModelState.currentFilter != parachainViewModelState.initialFilter,
            canReset: parachainViewModelState.currentFilter != CustomValidatorParachainListFilter.recommendedFilter()
        )
    }
}
