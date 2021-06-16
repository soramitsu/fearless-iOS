import Foundation
import FearlessUtils
import SoraFoundation

final class CustomValidatorListViewModelFactory {
    let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    private lazy var iconGenerator = PolkadotIconGenerator()

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
    }

    private func createHeaderViewModel(
        displayValidatorsCount: Int,
        totalValidatorsCount: Int,
        filter: CustomValidatorListFilter,
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
        from validators: [ElectedValidatorInfo],
        selectedValidators: Set<ElectedValidatorInfo>,
        filter: CustomValidatorListFilter,
        priceData: PriceData?,
        locale: Locale
    ) -> [CustomValidatorCellViewModel] {
        let apyFormatter = NumberFormatter.percent.localizableResource().value(for: locale)

        return validators.map { validator in
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
                isSelected: selectedValidators.contains(validator)
            )
        }
    }
}

extension CustomValidatorListViewModelFactory: CustomValidatorListViewModelFactoryProtocol {
    func createViewModel(
        from validators: [ElectedValidatorInfo],
        selectedValidators: Set<ElectedValidatorInfo>,
        totalValidatorsCount: Int,
        filter: CustomValidatorListFilter,
        priceData: PriceData?,
        locale: Locale
    ) -> CustomValidatorListViewModel {
        let headerViewModel = createHeaderViewModel(
            displayValidatorsCount: validators.count,
            totalValidatorsCount: totalValidatorsCount,
            filter: filter,
            locale: locale
        )

        let cellsViewModel = createCellsViewModel(
            from: validators,
            selectedValidators: selectedValidators,
            filter: filter,
            priceData: priceData,
            locale: locale
        )

        return CustomValidatorListViewModel(
            headerViewModel: headerViewModel,
            cellViewModels: cellsViewModel
        )
    }
}
