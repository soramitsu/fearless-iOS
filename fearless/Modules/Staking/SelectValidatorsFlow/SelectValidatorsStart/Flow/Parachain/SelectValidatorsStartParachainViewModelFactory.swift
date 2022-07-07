import Foundation

final class SelectValidatorsStartParachainViewModelFactory: SelectValidatorsStartViewModelFactoryProtocol {
    func buildViewModel(viewModelState: SelectValidatorsStartViewModelState) -> SelectValidatorsStartViewModel? {
        guard let parachainViewModelState = viewModelState as? SelectValidatorsStartParachainViewModelState else {
            return nil
        }

        return SelectValidatorsStartViewModel(
            selectedCount: parachainViewModelState.selectedCandidates?.count ?? 0,
            totalCount: nil
        )
    }

    func buildTextsViewModel(locale: Locale) -> SelectValidatorsStartTextsViewModel? {
        let steps = [R.string.localizable.stakingRecommendedHint1(preferredLanguages: locale.rLanguages),
                     R.string.localizable.stakingRecommendedHint2(preferredLanguages: locale.rLanguages)]

        return SelectValidatorsStartTextsViewModel(
            algoSteps: steps,
            stakingRecommendedTitle: R.string.localizable.stakingCollators(preferredLanguages: locale.rLanguages),
            algoSectionLabel: R.string.localizable.stakingStartChangeCollatorsSuggestedTitle(preferredLanguages: locale.rLanguages),
            algoDetailsLabel: R.string.localizable.stakingStartChangeCollatorsSuggestedSubtitle(preferredLanguages: locale.rLanguages),
            suggestedValidatorsWarningViewTitle: R.string.localizable.selectCollatorsWarning(preferredLanguages: locale.rLanguages),
            customValidatorsSectionLabel: R.string.localizable.customCollatorsTitle(preferredLanguages: locale.rLanguages),
            customValidatorsDetailsLabel: R.string.localizable.customCollatorsText(preferredLanguages: locale.rLanguages)
        )
    }
}
