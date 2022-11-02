import Foundation
import FearlessUtils

final class CustomValidatorListRelaychainViewModelFactory {
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let iconGenerator: IconGenerating

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
        priceData: PriceData?,
        locale: Locale,
        searchText: String?
    ) -> [CustomValidatorCellViewModel] {
        let apyFormatter = NumberFormatter.percent.localizableResource().value(for: locale)

        return validatorList.filter {
            guard let searchText = searchText, searchText.isNotEmpty else {
                return true
            }

            return $0.identity?.displayName.lowercased().contains(searchText.lowercased()) == true
        }.map { validator in
            let icon = try? self.iconGenerator.generateFromAddress(validator.address)

            let apy: NSAttributedString? = validator.stakeInfo.map { info in
                let stakeReturnString = apyFormatter.stringFromDecimal(info.stakeReturn) ?? ""
                let apyString = "APY \(stakeReturnString)"

                let apyStringAttributed = NSMutableAttributedString(string: apyString)
                apyStringAttributed.addAttribute(
                    .foregroundColor,
                    value: R.color.colorColdGreen() as Any,
                    range: (apyString as NSString).range(of: stakeReturnString)
                )
                return apyStringAttributed
            }

            let balanceViewModel = balanceViewModelFactory.balanceFromPrice(
                validator.totalStake,
                priceData: priceData
            ).value(for: locale)

            let stakedString = R.string.localizable.yourValidatorsValidatorTotalStake(
                "\(balanceViewModel.amount)",
                preferredLanguages: locale.rLanguages
            )

            return CustomValidatorCellViewModel(
                icon: icon,
                name: validator.identity?.displayName,
                address: validator.address,
                detailsAttributedString: apy,
                auxDetails: stakedString,
                shouldShowWarning: validator.oversubscribed,
                shouldShowError: validator.hasSlashes,
                isSelected: selectedValidatorList.contains(validator)
            )
        }
    }
}

extension CustomValidatorListRelaychainViewModelFactory: CustomValidatorListViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: CustomValidatorListViewModelState,
        priceData: PriceData?,
        locale: Locale,
        searchText: String?
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
            priceData: priceData,
            locale: locale,
            searchText: searchText
        )

        let proceedButtonTitle = relaychainViewModelState.selectedValidatorList.items.isEmpty
            ? R.string.localizable
            .stakingCustomProceedButtonDisabledTitle(
                relaychainViewModelState.maxTargets,
                preferredLanguages: locale.rLanguages
            )
            : R.string.localizable.stakingCustomProceedButtonEnabledTitle(
                relaychainViewModelState.selectedValidatorList.count,
                relaychainViewModelState.maxTargets,
                preferredLanguages: locale.rLanguages
            )

        return CustomValidatorListViewModel(
            headerViewModel: headerViewModel,
            cellViewModels: cellsViewModel,
            selectedValidatorsCount: relaychainViewModelState.selectedValidatorList.count,
            selectedValidatorsLimit: relaychainViewModelState.maxTargets,
            proceedButtonTitle: proceedButtonTitle,
            title: R.string.localizable.stakingCustomValidatorsListTitle(preferredLanguages: locale.rLanguages)
        )
    }
}
