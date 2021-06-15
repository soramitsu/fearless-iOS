import Foundation
import FearlessUtils
import SoraFoundation

final class CustomValidatorListViewModelFactory {
    private lazy var iconGenerator = PolkadotIconGenerator()

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
        locale: Locale
    ) -> [CustomValidatorCellViewModel] {
        let percentageAPYFormatter = NumberFormatter.percentBase.localizableResource()
        return validators.map { validator in
            let icon = try? self.iconGenerator.generateFromAddress(validator.address)

            let restakePercentage = percentageAPYFormatter
                .value(for: locale)
                .string(from: validator.stakeReturn as NSNumber)

            return CustomValidatorCellViewModel(
                icon: icon,
                name: validator.identity?.displayName ?? validator.address,
                apyPercentage: restakePercentage,
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
            locale: locale
        )

        return CustomValidatorListViewModel(
            headerViewModel: headerViewModel,
            cellViewModels: cellsViewModel
        )
    }
}
