import Foundation

final class SelectValidatorsStartParachainViewModelFactory: SelectValidatorsStartViewModelFactoryProtocol {
    func buildViewModel(viewModelState: SelectValidatorsStartViewModelState) -> SelectValidatorsStartViewModel? {
        guard
            let parachainViewModelState = viewModelState as? SelectValidatorsStartParachainViewModelState,
            let selectedCount = parachainViewModelState.selectedCandidates?.count
        else {
            return nil
        }

        return SelectValidatorsStartViewModel(
            selectedCount: selectedCount,
            totalCount: nil,
            recommendedValidatorListLoaded: parachainViewModelState.recommendedCandidates != nil
        )
    }

    func buildTextsViewModel(locale: Locale) -> SelectValidatorsStartTextsViewModel? {
        let steps = [R.string.localizable.stakingRecommendedHint1(preferredLanguages: locale.rLanguages),
                     R.string.localizable.stakingRecommendedFilterMinimumBond(preferredLanguages: locale.rLanguages)]

        return SelectValidatorsStartTextsViewModel(
            algoSteps: steps,
            stakingRecommendedTitle: R.string.localizable.stakingCollators(preferredLanguages: locale.rLanguages),
            algoSectionLabel: R.string.localizable.stakingStartChangeCollatorsSuggestedTitle(
                preferredLanguages: locale.rLanguages
            ),
            algoDetailsLabel: R.string.localizable.stakingStartChangeCollatorsSuggestedSubtitle(
                preferredLanguages: locale.rLanguages
            ),
            suggestedValidatorsWarningViewTitle: R.string.localizable.selectCollatorsWarning(
                preferredLanguages: locale.rLanguages
            ),
            customValidatorsSectionLabel: R.string.localizable.customCollatorsTitle(
                preferredLanguages: locale.rLanguages
            ),
            customValidatorsDetailsLabel: R.string.localizable.customCollatorsText(
                preferredLanguages: locale.rLanguages
            )
        )
    }
}
