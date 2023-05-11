import Foundation
import SSFUtils
import SoraFoundation
import BigInt

final class SelectedValidatorListParachainViewModelFactory {
    private var iconGenerator: IconGenerating
    private let chainAsset: ChainAsset
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    init(
        iconGenerator: IconGenerating,
        chainAsset: ChainAsset,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.iconGenerator = iconGenerator
        self.chainAsset = chainAsset
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
            .stakingFilterTitleRewardsApr(preferredLanguages: locale.rLanguages)

        return TitleWithSubtitleViewModel(
            title: title,
            subtitle: subtitle
        )
    }

    private func createCellsViewModel(
        from validatorList: [ParachainStakingCandidateInfo],
        locale: Locale
    ) -> [SelectedValidatorCellViewModel] {
        let apyFormatter = NumberFormatter.percent.localizableResource().value(for: locale)

        return validatorList.map { validator in
            let icon = try? self.iconGenerator.generateFromAddress(validator.address)

            let apy: NSAttributedString? = validator.subqueryData.map { info in
                let stakeReturnString = apyFormatter.stringFromDecimal(Decimal(info.apr)) ?? ""
                let apyString = "APY \(stakeReturnString)"

                let apyStringAttributed = NSMutableAttributedString(string: apyString)
                apyStringAttributed.addAttribute(
                    .foregroundColor,
                    value: R.color.colorColdGreen() as Any,
                    range: (apyString as NSString).range(of: stakeReturnString)
                )
                return apyStringAttributed
            }

            let totalStake = Decimal.fromSubstrateAmount(
                validator.metadata?.totalCounted ?? BigUInt.zero,
                precision: Int16(chainAsset.asset.precision)
            ) ?? Decimal.zero
            let balanceViewModel = balanceViewModelFactory.balanceFromPrice(
                totalStake,
                priceData: nil,
                usageCase: .listCrypto
            ).value(for: locale)
            let stakedString = R.string.localizable.yourValidatorsValidatorTotalStake(
                "\(balanceViewModel.amount)",
                preferredLanguages: locale.rLanguages
            )

            return SelectedValidatorCellViewModel(
                icon: icon,
                name: validator.identity?.displayName,
                address: validator.address,
                detailsAttributedString: apy,
                detailsAux: stakedString,
                shouldShowWarning: validator.oversubscribed,
                shouldShowError: false
            )
        }
    }
}

extension SelectedValidatorListParachainViewModelFactory: SelectedValidatorListViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: SelectedValidatorListViewModelState,
        locale: Locale
    ) -> SelectedValidatorListViewModel? {
        guard let parachainViewModelState = viewModelState as? SelectedValidatorListParachainViewModelState else {
            return nil
        }

        let headerViewModel = createHeaderViewModel(
            displayValidatorsCount: parachainViewModelState.selectedValidatorList.count,
            totalValidatorsCount: parachainViewModelState.maxTargets,
            locale: locale
        )

        let cellsViewModel = createCellsViewModel(
            from: parachainViewModelState.selectedValidatorList,
            locale: locale
        )

        return SelectedValidatorListViewModel(
            headerViewModel: headerViewModel,
            cellViewModels: cellsViewModel,
            limitIsExceeded: parachainViewModelState.selectedValidatorList.count > parachainViewModelState.maxTargets,
            selectedValidatorsLimit: parachainViewModelState.maxTargets
        )
    }
}
