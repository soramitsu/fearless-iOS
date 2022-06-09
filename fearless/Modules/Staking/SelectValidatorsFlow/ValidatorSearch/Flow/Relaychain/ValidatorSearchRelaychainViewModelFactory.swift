import Foundation
import FearlessUtils

final class ValidatorSearchRelaychainViewModelFactory {
    private lazy var iconGenerator = PolkadotIconGenerator()

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

            let detailsText = apyFormatter.string(
                from: validator.stakeReturn as NSNumber
            )

            return ValidatorSearchCellViewModel(
                icon: icon,
                name: validator.identity?.displayName,
                address: validator.address,
                details: detailsText,
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
