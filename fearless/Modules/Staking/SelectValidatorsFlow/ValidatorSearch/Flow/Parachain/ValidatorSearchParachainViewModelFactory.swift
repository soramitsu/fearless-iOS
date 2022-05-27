import Foundation
import FearlessUtils

final class ValidatorSearchParachainViewModelFactory {
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
        from displayValidatorList: [ParachainStakingCandidateInfo],
        selectedValidatorList: [ParachainStakingCandidateInfo],
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
