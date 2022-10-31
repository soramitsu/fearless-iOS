import Foundation
import FearlessUtils

final class ValidatorSearchRelaychainViewModelFactory {
    private var iconGenerator: IconGenerating
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    init(
        iconGenerator: IconGenerating,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.iconGenerator = iconGenerator
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    private func createHeaderViewModel(
        displayValidatorsCount: Int,
        locale: Locale
    ) -> TitleWithSubtitleViewModel {
        let title = R.string.localizable
            .commonSearchResultsNumber(
                displayValidatorsCount,
                preferredLanguages: locale.rLanguages
            )

        let subtitle = R.string.localizable
            .stakingFilterTitleRewards(preferredLanguages: locale.rLanguages)

        return TitleWithSubtitleViewModel(title: title, subtitle: subtitle)
    }

    private func createCellsViewModel(
        from displayValidatorList: [SelectedValidatorInfo],
        selectedValidatorList: [SelectedValidatorInfo],
        locale: Locale
    ) -> [ValidatorSearchCellViewModel] {
        let apyFormatter = NumberFormatter.percent.localizableResource().value(for: locale)

        return displayValidatorList.map { validator in
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
                priceData: nil
            ).value(for: locale)

            let stakedString = R.string.localizable.yourValidatorsValidatorTotalStake(
                "\(balanceViewModel.amount)",
                preferredLanguages: locale.rLanguages
            )

            return ValidatorSearchCellViewModel(
                icon: icon,
                name: validator.identity?.displayName,
                address: validator.address,
                details: apy,
                detailsAux: stakedString,
                shouldShowWarning: validator.oversubscribed,
                shouldShowError: validator.hasSlashes,
                isSelected: selectedValidatorList.contains(validator)
            )
        }
    }

    func createEmptyModel() -> ValidatorSearchViewModel {
        ValidatorSearchViewModel(
            headerViewModel: nil,
            cellViewModels: []
        )
    }
}

extension ValidatorSearchRelaychainViewModelFactory: ValidatorSearchViewModelFactoryProtocol {
    func buildViewModel(viewModelState: ValidatorSearchViewModelState, locale: Locale) -> ValidatorSearchViewModel? {
        guard let relaychainViewModelState = viewModelState as? ValidatorSearchRelaychainViewModelState else {
            return nil
        }

        guard !relaychainViewModelState.filteredValidatorList.isEmpty else {
            return createEmptyModel()
        }

        let headerViewModel = createHeaderViewModel(
            displayValidatorsCount: relaychainViewModelState.filteredValidatorList.count,
            locale: locale
        )

        let cellsViewModel = createCellsViewModel(
            from: relaychainViewModelState.filteredValidatorList,
            selectedValidatorList: relaychainViewModelState.selectedValidatorList,
            locale: locale
        )

        return ValidatorSearchViewModel(
            headerViewModel: headerViewModel,
            cellViewModels: cellsViewModel
        )
    }
}
