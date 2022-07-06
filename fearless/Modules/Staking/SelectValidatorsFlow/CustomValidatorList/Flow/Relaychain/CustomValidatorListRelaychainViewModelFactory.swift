import Foundation
import FearlessUtils

class CustomValidatorListRelaychainViewModelFactory {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private var iconGenerator: IconGenerating

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        iconGenerator: IconGenerating
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.iconGenerator = iconGenerator
    }

    private func createHeaderViewModel(
        displayValidatorsCount: Int,
        totalValidatorsCount: Int,
        filter: CustomValidatorRelaychainListFilter,
        locale: Locale
    ) -> TitleWithSubtitleViewModel {
        let title = R.string.localizable
            .stakingCustomHeaderValidatorsTitle(
                displayValidatorsCount,
                totalValidatorsCount,
                preferredLanguages: locale.rLanguages
            )

        let subtitle: String
        switch filter.sortedBy {
        case .estimatedReward:
            subtitle = R.string.localizable
                .stakingFilterTitleRewards(preferredLanguages: locale.rLanguages)
        case .ownStake:
            subtitle = R.string.localizable
                .stakingFilterTitleOwnStake(preferredLanguages: locale.rLanguages)
        case .totalStake:
            subtitle = R.string.localizable
                .stakingValidatorTotalStake(preferredLanguages: locale.rLanguages)
        }

        return TitleWithSubtitleViewModel(title: title, subtitle: subtitle)
    }

    private func createCellsViewModel(
        from validatorList: [SelectedValidatorInfo],
        selectedValidatorList: [SelectedValidatorInfo],
        filter: CustomValidatorRelaychainListFilter,
        priceData: PriceData?,
        locale: Locale
    ) -> [CustomValidatorCellViewModel] {
        let apyFormatter = NumberFormatter.percent.localizableResource().value(for: locale)

        return validatorList.map { validator in
            let icon = try? self.iconGenerator.generateFromAddress(validator.address)

            let detailsText: String?
            let auxDetailsText: String?

            switch filter.sortedBy {
            case .estimatedReward:
                detailsText =
                    apyFormatter.string(from: validator.stakeReturn as NSNumber)
                auxDetailsText = nil

            case .ownStake:
                let balanceViewModel = balanceViewModelFactory.balanceFromPrice(
                    validator.ownStake,
                    priceData: priceData
                ).value(for: locale)

                detailsText = balanceViewModel.amount
                auxDetailsText = balanceViewModel.price

            case .totalStake:
                let balanceViewModel = balanceViewModelFactory.balanceFromPrice(
                    validator.totalStake,
                    priceData: priceData
                ).value(for: locale)

                detailsText = balanceViewModel.amount
                auxDetailsText = balanceViewModel.price
            }

            return CustomValidatorCellViewModel(
                icon: icon,
                name: validator.identity?.displayName,
                address: validator.address,
                details: detailsText,
                auxDetails: auxDetailsText,
                shouldShowWarning: validator.oversubscribed,
                shouldShowError: validator.hasSlashes,
                isSelected: selectedValidatorList.contains(validator)
            )
        }
    }

    func createViewModel(
        from displayValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: [SelectedValidatorInfo],
        totalValidatorsCount: Int,
        filter: CustomValidatorRelaychainListFilter,
        priceData: PriceData?,
        locale: Locale
    ) -> CustomValidatorListViewModel {
        let headerViewModel = createHeaderViewModel(
            displayValidatorsCount: displayValidatorList.count,
            totalValidatorsCount: totalValidatorsCount,
            filter: filter,
            locale: locale
        )

        let cellsViewModel = createCellsViewModel(
            from: displayValidatorList,
            selectedValidatorList: selectedValidatorList,
            filter: filter,
            priceData: priceData,
            locale: locale
        )

        return CustomValidatorListViewModel(
            headerViewModel: headerViewModel,
            cellViewModels: cellsViewModel,
            selectedValidatorsCount: selectedValidatorList.count,
            proceedButtonTitle: R.string.localizable
                .stakingCustomProceedButtonDisabledTitle(
                    selectedValidatorList.count,
                    preferredLanguages: locale.rLanguages
                )
        )
    }
}

extension CustomValidatorListRelaychainViewModelFactory: CustomValidatorListViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: CustomValidatorListViewModelState,
        priceData: PriceData?,
        locale: Locale
    ) -> CustomValidatorListViewModel? {
        guard let relaychainViewModelState = viewModelState as? CustomValidatorListRelaychainViewModelState else {
            return nil
        }

        let headerViewModel = createHeaderViewModel(
            displayValidatorsCount: relaychainViewModelState.filteredValidatorList.count,
            totalValidatorsCount: relaychainViewModelState.fullValidatorList.count,
            filter: relaychainViewModelState.filter,
            locale: locale
        )

        let cellsViewModel = createCellsViewModel(
            from: relaychainViewModelState.filteredValidatorList,
            selectedValidatorList: relaychainViewModelState.selectedValidatorList.items,
            filter: relaychainViewModelState.filter,
            priceData: priceData,
            locale: locale
        )

        return CustomValidatorListViewModel(
            headerViewModel: headerViewModel,
            cellViewModels: cellsViewModel,
            selectedValidatorsCount: relaychainViewModelState.selectedValidatorList.count,
            proceedButtonTitle: R.string.localizable
                .stakingCustomProceedButtonDisabledTitle(
                    relaychainViewModelState.selectedValidatorList.count,
                    preferredLanguages: locale.rLanguages
                )
        )
    }
}
