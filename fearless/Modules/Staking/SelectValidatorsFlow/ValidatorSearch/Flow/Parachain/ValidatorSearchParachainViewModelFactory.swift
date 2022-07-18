import Foundation
import FearlessUtils

final class ValidatorSearchParachainViewModelFactory {
    private var iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
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

        return displayValidatorList.map { validator in
            let icon = try? self.iconGenerator.generateFromAddress(validator.address)

            let detailsText = apyFormatter.string(
                from: (validator.subqueryData?.apr ?? 0.0) as NSNumber
            )

            // TODO: Real oversubscribed and hasSlashes value
            return ValidatorSearchCellViewModel(
                icon: icon,
                name: validator.identity?.displayName,
                address: validator.address,
                details: detailsText,
                shouldShowWarning: false,
                shouldShowError: false,
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
