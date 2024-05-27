import Foundation
import SSFUtils
import SSFModels

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

    private func createCellViewModel(
        validator: SelectedValidatorInfo,
        selectedValidatorList: [SelectedValidatorInfo],
        priceData: PriceData?,
        locale: Locale
    ) -> CustomValidatorCellViewModel {
        let icon = try? iconGenerator.generateFromAddress(validator.address)
        let apyFormatter = NumberFormatter.percent.localizableResource().value(for: locale)

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

        let comissionPercent = NumberFormatter.percent.stringFromDecimal(validator.commission)
        let comission: NSAttributedString? = comissionPercent.map { comission in
            let apyString = "\(R.string.localizable.validatorInfoComissionTitle(preferredLanguages: locale.rLanguages)) \(comission)"

            let apyStringAttributed = NSMutableAttributedString(string: apyString)
            apyStringAttributed.addAttribute(
                .foregroundColor,
                value: R.color.colorColdGreen() as Any,
                range: (apyString as NSString).range(of: comission)
            )
            return apyStringAttributed
        }

        let balanceViewModel = balanceViewModelFactory.balanceFromPrice(
            validator.totalStake,
            priceData: priceData,
            usageCase: .listCrypto
        ).value(for: locale)

        let stakedString = R.string.localizable.yourValidatorsValidatorTotalStake(
            "\(balanceViewModel.amount)",
            preferredLanguages: locale.rLanguages
        )

        let detailsAttributedString = validator.elected ? apy : comission
        let auxDetails = validator.elected ? stakedString : nil
        let showWarning = validator.elected ? validator.oversubscribed : validator.blocked

        return CustomValidatorCellViewModel(
            icon: icon,
            name: validator.identity?.displayName,
            address: validator.address,
            detailsAttributedString: detailsAttributedString,
            auxDetails: auxDetails,
            shouldShowWarning: showWarning,
            shouldShowError: validator.hasSlashes,
            isSelected: selectedValidatorList.contains(validator)
        )
    }

    private func createSectionViewModels(
        from validatorList: [SelectedValidatorInfo],
        selectedValidatorList: [SelectedValidatorInfo],
        priceData: PriceData?,
        locale: Locale,
        searchText: String?
    ) -> [CustomValidatorListSectionViewModel] {
        let filteredValidatorList = validatorList
            .filter {
                guard let searchText = searchText, searchText.isNotEmpty else {
                    return true
                }

                let foundByName = $0.identity?.displayName.lowercased().contains(searchText.lowercased()) == true
                let foundByAddress = $0.address.lowercased().contains(searchText.lowercased())

                return foundByName || foundByAddress
            }

        let electedViewModels = filteredValidatorList
            .filter { $0.elected }
            .map { validator in
                createCellViewModel(validator: validator, selectedValidatorList: selectedValidatorList, priceData: priceData, locale: locale)
            }.sorted(by: { viewModel1, viewModel2 in
                viewModel1.isSelected.intValue > viewModel2.isSelected.intValue
            })

        let notElectedViewModels = filteredValidatorList
            .filter { !$0.elected }
            .map { validator in
                createCellViewModel(validator: validator, selectedValidatorList: selectedValidatorList, priceData: priceData, locale: locale)
            }.sorted(by: { viewModel1, viewModel2 in
                viewModel1.isSelected.intValue > viewModel2.isSelected.intValue
            })

        var sections: [CustomValidatorListSectionViewModel] = []

        if electedViewModels.isNotEmpty {
            let section = CustomValidatorListSectionViewModel(
                title: R.string.localizable.stakingYourElectedFormat("\(electedViewModels.count)", preferredLanguages: locale.rLanguages),
                cells: electedViewModels,
                icon: R.image.iconAlgoItem()!
            )
            sections.append(section)
        }

        if notElectedViewModels.isNotEmpty {
            let section = CustomValidatorListSectionViewModel(
                title: R.string.localizable.stakingYourNotElectedFormat("\(notElectedViewModels.count)", preferredLanguages: locale.rLanguages),
                cells: notElectedViewModels,
                icon: R.image.iconLightPending()!
            )
            sections.append(section)
        }
        return sections
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

        let sections = createSectionViewModels(
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
            sections: sections,
            selectedValidatorsCount: relaychainViewModelState.selectedValidatorList.count,
            selectedValidatorsLimit: relaychainViewModelState.maxTargets,
            proceedButtonTitle: proceedButtonTitle,
            title: R.string.localizable.stakingCustomValidatorsListTitle(preferredLanguages: locale.rLanguages)
        )
    }
}
