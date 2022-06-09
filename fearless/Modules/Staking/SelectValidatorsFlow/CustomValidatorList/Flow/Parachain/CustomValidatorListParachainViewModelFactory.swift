import Foundation
import FearlessUtils
import BigInt

class CustomValidatorListParachainViewModelFactory {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    let chainAsset: ChainAsset

    private lazy var iconGenerator = PolkadotIconGenerator()

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chainAsset: ChainAsset
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chainAsset = chainAsset
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
                .stakingFilterTitleRewards(preferredLanguages: locale.rLanguages)
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
        filter: CustomValidatorParachainListFilter,
        priceData: PriceData?,
        locale: Locale
    ) -> [CustomValidatorCellViewModel] {
        let apyFormatter = NumberFormatter.percent.localizableResource().value(for: locale)

        return collatorList.map { collator in
            let icon = try? self.iconGenerator.generateFromAddress(collator.address)

            let detailsText: String?
            let auxDetailsText: String?

            switch filter.sortedBy {
            case .estimatedReward:
                // TODO: Real stake return value
                detailsText =
                    apyFormatter.string(from: 0 as NSNumber)
                auxDetailsText = nil

            case .ownStake:
                let bond = Decimal.fromSubstrateAmount(
                    collator.metadata?.bond ?? BigUInt.zero,
                    precision: Int16(chainAsset.asset.precision)
                ) ?? Decimal.zero
                let balanceViewModel = balanceViewModelFactory.balanceFromPrice(
                    bond,
                    priceData: priceData
                ).value(for: locale)

                detailsText = balanceViewModel.amount
                auxDetailsText = balanceViewModel.price

            case .effectiveAmountBonded:
                let totalStake = Decimal.fromSubstrateAmount(
                    collator.metadata?.totalCounted ?? BigUInt.zero,
                    precision: Int16(chainAsset.asset.precision)
                ) ?? Decimal.zero
                let balanceViewModel = balanceViewModelFactory.balanceFromPrice(
                    totalStake,
                    priceData: priceData
                ).value(for: locale)

                detailsText = balanceViewModel.amount
                auxDetailsText = balanceViewModel.price
            case .delegations:
                detailsText = collator.metadata?.delegationCount
                auxDetailsText = ""
            case .minimumBond:
                let minimumBond = Decimal.fromSubstrateAmount(
                    collator.metadata?.totalCounted ?? BigUInt.zero,
                    precision: Int16(chainAsset.asset.precision)
                ) ?? Decimal.zero
                detailsText = minimumBond.stringWithPointSeparator
                auxDetailsText = ""
            }

            // TODO: Real hasSlashes and oversubscribed value
            return CustomValidatorCellViewModel(
                icon: icon,
                name: collator.identity?.displayName,
                address: collator.address,
                details: detailsText,
                auxDetails: auxDetailsText,
                shouldShowWarning: false,
                shouldShowError: false,
                isSelected: selectedCollatorList.contains(collator)
            )
        }
    }

    func createViewModel(
        from displayCollatorList: [ParachainStakingCandidateInfo],
        selectedCollatorList: [ParachainStakingCandidateInfo],
        totalCollatorsCount: Int,
        filter: CustomValidatorParachainListFilter,
        priceData: PriceData?,
        locale: Locale
    ) -> CustomValidatorListViewModel {
        let headerViewModel = createHeaderViewModel(
            displayCollatorsCount: displayCollatorList.count,
            totalCollatorsCount: totalCollatorsCount,
            filter: filter,
            locale: locale
        )

        let cellsViewModel = createCellsViewModel(
            from: displayCollatorList,
            selectedCollatorList: selectedCollatorList,
            filter: filter,
            priceData: priceData,
            locale: locale
        )

        return CustomValidatorListViewModel(
            headerViewModel: headerViewModel,
            cellViewModels: cellsViewModel,
            selectedValidatorsCount: selectedCollatorList.count
        )
    }
}

extension CustomValidatorListParachainViewModelFactory: CustomValidatorListViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: CustomValidatorListViewModelState,
        priceData: PriceData?,
        locale: Locale
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
            filter: parachainViewModelState.filter,
            priceData: priceData,
            locale: locale
        )

        return CustomValidatorListViewModel(
            headerViewModel: headerViewModel,
            cellViewModels: cellsViewModel,
            selectedValidatorsCount: parachainViewModelState.selectedValidatorList.count
        )
    }
}
