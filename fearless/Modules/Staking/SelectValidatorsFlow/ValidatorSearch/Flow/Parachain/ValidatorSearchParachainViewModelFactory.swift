import Foundation
import FearlessUtils
import BigInt

final class ValidatorSearchParachainViewModelFactory {
    private var iconGenerator: IconGenerating
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let chainAsset: ChainAsset

    init(
        iconGenerator: IconGenerating,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chainAsset: ChainAsset
    ) {
        self.iconGenerator = iconGenerator
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chainAsset = chainAsset
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
            .stakingFilterTitleRewardsApr(preferredLanguages: locale.rLanguages)

        return TitleWithSubtitleViewModel(title: title, subtitle: subtitle)
    }

    private func createCellsViewModel(
        from displayValidatorList: [ParachainStakingCandidateInfo],
        selectedValidatorList: [ParachainStakingCandidateInfo],
        locale: Locale
    ) -> [ValidatorSearchCellViewModel] {
        let apyFormatter = NumberFormatter.percentPlain.localizableResource().value(for: locale)

        return displayValidatorList.map { collator in
            let icon = try? self.iconGenerator.generateFromAddress(collator.address)

            let apy: NSAttributedString? = collator.subqueryData.map { info in
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
                collator.metadata?.totalCounted ?? BigUInt.zero,
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

            return ValidatorSearchCellViewModel(
                icon: icon,
                name: collator.identity?.displayName,
                address: collator.address,
                detailsAttributedString: apy,
                detailsAux: stakedString,
                shouldShowWarning: collator.oversubscribed,
                shouldShowError: false,
                isSelected: selectedValidatorList.contains(collator)
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

extension ValidatorSearchParachainViewModelFactory: ValidatorSearchViewModelFactoryProtocol {
    func buildViewModel(viewModelState: ValidatorSearchViewModelState, locale: Locale) -> ValidatorSearchViewModel? {
        guard let parachainViewModelState = viewModelState as? ValidatorSearchParachainViewModelState else {
            return nil
        }

        guard !parachainViewModelState.filteredValidatorList.isEmpty else {
            return createEmptyModel()
        }

        let headerViewModel = createHeaderViewModel(
            displayValidatorsCount: parachainViewModelState.filteredValidatorList.count,
            locale: locale
        )

        let cellsViewModel = createCellsViewModel(
            from: parachainViewModelState.filteredValidatorList,
            selectedValidatorList: parachainViewModelState.selectedValidatorList,
            locale: locale
        )

        return ValidatorSearchViewModel(
            headerViewModel: headerViewModel,
            cellViewModels: cellsViewModel
        )
    }
}
