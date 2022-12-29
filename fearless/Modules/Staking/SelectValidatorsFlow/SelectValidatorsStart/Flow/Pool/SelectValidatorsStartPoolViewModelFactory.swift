import Foundation

// swiftlint:disable type_name
final class SelectValidatorsStartPoolInitiatedViewModelFactory: SelectValidatorsStartViewModelFactoryProtocol {
    func buildViewModel(viewModelState: SelectValidatorsStartViewModelState) -> SelectValidatorsStartViewModel? {
        guard
            let relaychainViewModelState = viewModelState as? SelectValidatorsStartPoolInitiatedViewModelState,
            let selectedCount = relaychainViewModelState.electedValidators?.count,
            let totalCount = relaychainViewModelState.maxNominations
        else {
            return nil
        }

        return SelectValidatorsStartViewModel(
            selectedCount: selectedCount,
            totalCount: totalCount,
            recommendedValidatorListLoaded: relaychainViewModelState.recommendedValidators != nil
        )
    }

    func buildTextsViewModel(locale: Locale) -> SelectValidatorsStartTextsViewModel? {
        let steps = [R.string.localizable.stakingRecommendedHint1(preferredLanguages: locale.rLanguages),
                     R.string.localizable.stakingRecommendedHint2(preferredLanguages: locale.rLanguages),
                     R.string.localizable.stakingRecommendedHint3(preferredLanguages: locale.rLanguages),
                     R.string.localizable.stakingRecommendedHint4(preferredLanguages: locale.rLanguages),
                     R.string.localizable.stakingRecommendedHint5(preferredLanguages: locale.rLanguages)]

        return SelectValidatorsStartTextsViewModel(
            algoSteps: steps,
            stakingRecommendedTitle: R.string.localizable
                .stakingRecommendedTitle(preferredLanguages: locale.rLanguages),
            algoSectionLabel: R.string.localizable
                .stakingSelectValidatorsRecommendedTitle(preferredLanguages: locale.rLanguages),
            algoDetailsLabel: R.string.localizable
                .stakingSelectValidatorsRecommendedDesc(preferredLanguages: locale.rLanguages),
            suggestedValidatorsWarningViewTitle: R.string.localizable
                .selectValidatorsDisclaimer(preferredLanguages: locale.rLanguages),
            customValidatorsSectionLabel: R.string.localizable
                .stakingSelectValidatorsCustomTitle(preferredLanguages: locale.rLanguages),
            customValidatorsDetailsLabel: R.string.localizable
                .stakingSelectValidatorsCustomDesc(preferredLanguages: locale.rLanguages)
        )
    }
}

final class SelectValidatorsStartPoolExistingViewModelFactory: SelectValidatorsStartViewModelFactoryProtocol {
    func buildViewModel(viewModelState: SelectValidatorsStartViewModelState) -> SelectValidatorsStartViewModel? {
        guard
            let relaychainViewModelState = viewModelState as? SelectValidatorsStartPoolExistingViewModelState,
            let selectedCount = relaychainViewModelState.electedValidators?.count,
            let totalCount = relaychainViewModelState.maxNominations
        else {
            return nil
        }

        return SelectValidatorsStartViewModel(
            selectedCount: selectedCount,
            totalCount: totalCount,
            recommendedValidatorListLoaded: relaychainViewModelState.recommendedValidators != nil
        )
    }

    func buildTextsViewModel(locale: Locale) -> SelectValidatorsStartTextsViewModel? {
        let steps = [R.string.localizable.stakingRecommendedHint1(preferredLanguages: locale.rLanguages),
                     R.string.localizable.stakingRecommendedHint2(preferredLanguages: locale.rLanguages),
                     R.string.localizable.stakingRecommendedHint3(preferredLanguages: locale.rLanguages),
                     R.string.localizable.stakingRecommendedHint4(preferredLanguages: locale.rLanguages),
                     R.string.localizable.stakingRecommendedHint5(preferredLanguages: locale.rLanguages)]

        return SelectValidatorsStartTextsViewModel(
            algoSteps: steps,
            stakingRecommendedTitle: R.string.localizable
                .stakingRecommendedTitle(preferredLanguages: locale.rLanguages),
            algoSectionLabel: R.string.localizable
                .stakingSelectValidatorsRecommendedTitle(preferredLanguages: locale.rLanguages),
            algoDetailsLabel: R.string.localizable
                .stakingSelectValidatorsRecommendedDesc(preferredLanguages: locale.rLanguages),
            suggestedValidatorsWarningViewTitle: R.string.localizable
                .selectValidatorsDisclaimer(preferredLanguages: locale.rLanguages),
            customValidatorsSectionLabel: R.string.localizable
                .stakingSelectValidatorsCustomTitle(preferredLanguages: locale.rLanguages),
            customValidatorsDetailsLabel: R.string.localizable
                .stakingSelectValidatorsCustomDesc(preferredLanguages: locale.rLanguages)
        )
    }
}
