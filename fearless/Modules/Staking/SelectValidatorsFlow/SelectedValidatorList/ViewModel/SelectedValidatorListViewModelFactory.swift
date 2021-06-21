import Foundation
import FearlessUtils
import SoraFoundation

final class SelectedValidatorListViewModelFactory {
    private lazy var iconGenerator = PolkadotIconGenerator()
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
        from validators: [ElectedValidatorInfo],
        locale: Locale
    ) -> [SelectedValidatorCellViewModel] {
        let apyFormatter = NumberFormatter.percent.localizableResource().value(for: locale)

        return validators.map { validator in
            let icon = try? self.iconGenerator.generateFromAddress(validator.address)

            let detailsText = apyFormatter.string(from: validator.stakeReturn as NSNumber)

            return SelectedValidatorCellViewModel(
                icon: icon,
                name: validator.identity?.displayName,
                address: validator.address,
                details: detailsText
            )
        }
    }
}

extension SelectedValidatorListViewModelFactory: SelectedValidatorListViewModelFactoryProtocol {
    func createViewModel(
        from validators: [ElectedValidatorInfo],
        totalValidatorsCount: Int,
        locale: Locale
    ) -> SelectedValidatorListViewModel {
        let headerViewModel = createHeaderViewModel(
            displayValidatorsCount: validators.count,
            totalValidatorsCount: totalValidatorsCount,
            locale: locale
        )

        let cellsViewModel = createCellsViewModel(
            from: validators,
            locale: locale
        )

        return SelectedValidatorListViewModel(
            headerViewModel: headerViewModel,
            cellViewModels: cellsViewModel,
            limitIsExceeded: validators.count > totalValidatorsCount
        )
    }
}
