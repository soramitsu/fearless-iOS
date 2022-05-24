import Foundation
import FearlessUtils
import SoraFoundation

final class SelectedValidatorListRelaychainViewModelFactory {
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
        from validatorList: [SelectedValidatorInfo],
        locale: Locale
    ) -> [SelectedValidatorCellViewModel] {
        let apyFormatter = NumberFormatter.percent.localizableResource().value(for: locale)

        return validatorList.map { validator in
            let icon = try? self.iconGenerator.generateFromAddress(validator.address)

            let detailsText = apyFormatter.string(from: validator.stakeReturn as NSNumber)

            return SelectedValidatorCellViewModel(
                icon: icon,
                name: validator.identity?.displayName,
                address: validator.address,
                details: detailsText,
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
