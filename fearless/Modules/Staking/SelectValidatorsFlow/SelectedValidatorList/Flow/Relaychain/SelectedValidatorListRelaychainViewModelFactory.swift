import Foundation
import FearlessUtils
import SoraFoundation

final class SelectedValidatorListRelaychainViewModelFactory {
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
        totalValidatorsCount: Int,
        locale: Locale
    ) -> TitleWithSubtitleViewModel {
        let title = R.string.localizable
            .stakingCustomHeaderValidatorsTitle(
                displayValidatorsCount,
                totalValidatorsCount,
                preferredLanguages: locale.rLanguages
            )

        let subtitle = R.string.localizable
            .stakingFilterTitleRewards(preferredLanguages: locale.rLanguages)

        return TitleWithSubtitleViewModel(
            title: title,
            subtitle: subtitle
        )
    }

    private func createCellsViewModel(
        from validatorList: [SelectedValidatorInfo],
        locale: Locale
    ) -> [SelectedValidatorCellViewModel] {
        let apyFormatter = NumberFormatter.percent.localizableResource().value(for: locale)

        return validatorList.map { validator in
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

            let name = validator.identity?.displayName ?? validator.address

            return SelectedValidatorCellViewModel(
                icon: icon,
                name: name,
                address: validator.address,
                detailsAttributedString: apy,
                detailsAux: stakedString,
                shouldShowWarning: validator.oversubscribed,
                shouldShowError: validator.hasSlashes
            )
        }
    }
}

extension SelectedValidatorListRelaychainViewModelFactory: SelectedValidatorListViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: SelectedValidatorListViewModelState,
        locale: Locale
    ) -> SelectedValidatorListViewModel? {
        guard let relaychainViewModelState = viewModelState as? SelectedValidatorListRelaychainViewModelState else {
            return nil
        }

        let headerViewModel = createHeaderViewModel(
            displayValidatorsCount: relaychainViewModelState.selectedValidatorList.count,
            totalValidatorsCount: relaychainViewModelState.maxTargets,
            locale: locale
        )

        let cellsViewModel = createCellsViewModel(
            from: relaychainViewModelState.selectedValidatorList,
            locale: locale
        )

        return SelectedValidatorListViewModel(
            headerViewModel: headerViewModel,
            cellViewModels: cellsViewModel,
            limitIsExceeded: relaychainViewModelState.selectedValidatorList.count > relaychainViewModelState.maxTargets,
            selectedValidatorsLimit: relaychainViewModelState.maxTargets
        )
    }
}
