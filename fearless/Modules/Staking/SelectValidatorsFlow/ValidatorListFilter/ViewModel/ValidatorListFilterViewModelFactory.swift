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
        let cellViewModels: [ValidatorListFilterCellViewModel] =
            ValidatorListFilterRow.allCases.map { row in
                switch row {
                case .withoutIdentity:
                    return ValidatorListFilterCellViewModel(
                        title: row.title.value(for: locale),
                        subtitle: row.subtitle?.value(for: locale),
                        isSelected: !filter.allowsNoIdentity
                    )

                case .slashed:
                    return ValidatorListFilterCellViewModel(
                        title: row.title.value(for: locale),
                        subtitle: row.subtitle?.value(for: locale),
                        isSelected: !filter.allowsSlashed
                    )

                case .oversubscribed:
                    return ValidatorListFilterCellViewModel(
                        title: row.title.value(for: locale),
                        subtitle: row.subtitle?.value(for: locale),
                        isSelected: !filter.allowsOversubscribed
                    )

                case .clusterLimit:
                    let allowsUnlimitedClusters = filter.allowsClusters == .unlimited
                    return ValidatorListFilterCellViewModel(
                        title: row.title.value(for: locale),
                        subtitle: row.subtitle?.value(for: locale),
                        isSelected: !allowsUnlimitedClusters
                    )
                }
            }

        let title = R.string.localizable.walletFiltersTitle(
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
        let cellViewModels: [ValidatorListFilterCellViewModel] =
            ValidatorListSortRow.allCases.map { row in
                switch row {
                case .estimatedReward:
                    let title = R.string.localizable
                        .stakingValidatorApyPercent(
                            preferredLanguages: locale.rLanguages
                        )
                    return ValidatorListFilterCellViewModel(
                        title: title,
                        subtitle: nil,
                        isSelected: filter.sortedBy == .estimatedReward
                    )

                case .ownStake:
                    let title = R.string.localizable
                        .stakingFilterTitleOwnStakeToken(
                            token,
                            preferredLanguages: locale.rLanguages
                        )
                    return ValidatorListFilterCellViewModel(
                        title: title,
                        subtitle: nil,
                        isSelected: filter.sortedBy == .ownStake
                    )

                case .totalStake:
                    let title = R.string.localizable
                        .stakingValidatorTotalStakeToken(
                            token,
                            preferredLanguages: locale.rLanguages
                        )
                    return ValidatorListFilterCellViewModel(
                        title: title,
                        subtitle: nil,
                        isSelected: filter.sortedBy == .totalStake
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
