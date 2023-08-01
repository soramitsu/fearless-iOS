import Foundation
import SSFUtils
import SSFModels
import BigInt

final class CustomValidatorListParachainViewModelFactory {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let chainAsset: ChainAsset
    private var iconGenerator: IconGenerating

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chainAsset: ChainAsset,
        iconGenerator: IconGenerating
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chainAsset = chainAsset
        self.iconGenerator = iconGenerator
    }

    private func createHeaderViewModel(
        displayCollatorsCount: Int,
        totalCollatorsCount: Int,
        filter: CustomValidatorParachainListFilter,
        locale: Locale
    ) -> TitleWithSubtitleViewModel {
        let title = R.string.localizable
            .stakingCustomHeaderValidatorsTitle(
                displayCollatorsCount,
                totalCollatorsCount,
                preferredLanguages: locale.rLanguages
            )

        let subtitle: String
        switch filter.sortedBy {
        case .estimatedReward:
            subtitle = R.string.localizable
                .stakingFilterTitleRewardsApr(preferredLanguages: locale.rLanguages)
        case .ownStake:
            subtitle = R.string.localizable
                .stakingFilterTitleOwnStake(preferredLanguages: locale.rLanguages)
        case .effectiveAmountBonded:
            subtitle = R.string.localizable
                .stakingValidatorTotalStake(preferredLanguages: locale.rLanguages)
        case .delegations:
            subtitle = R.string.localizable
                .stakingValidatorTotalStake(preferredLanguages: locale.rLanguages)
        case .minimumBond:
            subtitle = R.string.localizable
                .stakingValidatorTotalStake(preferredLanguages: locale.rLanguages)
        }

        return TitleWithSubtitleViewModel(title: title, subtitle: subtitle)
    }

    private func createCellsViewModel(
        from collatorList: [ParachainStakingCandidateInfo],
        selectedCollatorList: [ParachainStakingCandidateInfo],
        priceData: PriceData?,
        locale: Locale,
        searchText: String?
    ) -> [CustomValidatorCellViewModel] {
        let apyFormatter = NumberFormatter.percentPlain.localizableResource().value(for: locale)

        return collatorList.filter {
            guard let searchText = searchText, searchText.isNotEmpty else {
                return true
            }

            let foundByName = $0.identity?.displayName.lowercased().contains(searchText.lowercased()) == true
            let foundByAddress = $0.address.lowercased().contains(searchText.lowercased())

            return foundByName || foundByAddress
        }.map { collator in
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
                priceData: priceData,
                usageCase: .listCrypto
            ).value(for: locale)
            let stakedString = R.string.localizable.yourValidatorsValidatorTotalStake(
                "\(balanceViewModel.amount)",
                preferredLanguages: locale.rLanguages
            )

            return CustomValidatorCellViewModel(
                icon: icon,
                name: collator.identity?.displayName,
                address: collator.address,
                detailsAttributedString: apy,
                auxDetails: stakedString,
                shouldShowWarning: false,
                shouldShowError: false,
                isSelected: selectedCollatorList.contains(collator)
            )
        }
    }
}

extension CustomValidatorListParachainViewModelFactory: CustomValidatorListViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: CustomValidatorListViewModelState,
        priceData: PriceData?,
        locale: Locale,
        searchText: String?
    ) -> CustomValidatorListViewModel? {
        guard let parachainViewModelState = viewModelState as? CustomValidatorListParachainViewModelState else {
            return nil
        }

        let headerViewModel = createHeaderViewModel(
            displayCollatorsCount: parachainViewModelState.filteredValidatorList.count,
            totalCollatorsCount: parachainViewModelState.candidates.count,
            filter: parachainViewModelState.filter,
            locale: locale
        )

        let cellsViewModel = createCellsViewModel(
            from: parachainViewModelState.filteredValidatorList,
            selectedCollatorList: parachainViewModelState.selectedValidatorList.items,
            priceData: priceData,
            locale: locale,
            searchText: searchText
        )

        return CustomValidatorListViewModel(
            headerViewModel: headerViewModel,
            cellViewModels: cellsViewModel,
            selectedValidatorsCount: parachainViewModelState.selectedValidatorList.count,
            selectedValidatorsLimit: nil,
            proceedButtonTitle: R.string.localizable
                .stakingStakeWithSelectedTitle(
                    preferredLanguages: locale.rLanguages
                ),
            title: R.string.localizable.stakingCustomCollatorsTitle(preferredLanguages: locale.rLanguages)
        )
    }
}
