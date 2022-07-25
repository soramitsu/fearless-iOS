import Foundation
import FearlessUtils
import SoraFoundation

final class SelectedValidatorListParachainViewModelFactory {
    private var iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }

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
            .stakingFilterTitleRewardsApr(preferredLanguages: locale.rLanguages)

        return TitleWithSubtitleViewModel(
            title: title,
            subtitle: subtitle
        )
    }

    private func createCellsViewModel(
        from validatorList: [ParachainStakingCandidateInfo],
        locale: Locale
    ) -> [SelectedValidatorCellViewModel] {
        let apyFormatter = NumberFormatter.percent.localizableResource().value(for: locale)

        return validatorList.map { validator in
            let icon = try? self.iconGenerator.generateFromAddress(validator.address)

            let detailsText = apyFormatter.string(from: validator.stakeReturn as NSNumber)

            // TODO: Real hasSlashes value
            return SelectedValidatorCellViewModel(
                icon: icon,
                name: validator.identity?.displayName,
                address: validator.address,
                details: detailsText,
                shouldShowWarning: validator.oversubscribed,
                shouldShowError: false
            )
        }
    }
}

extension SelectedValidatorListParachainViewModelFactory: SelectedValidatorListViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: SelectedValidatorListViewModelState,
        locale: Locale
    ) -> SelectedValidatorListViewModel? {
        guard let parachainViewModelState = viewModelState as? SelectedValidatorListParachainViewModelState else {
            return nil
        }

        let headerViewModel = createHeaderViewModel(
            displayValidatorsCount: parachainViewModelState.selectedValidatorList.count,
            totalValidatorsCount: parachainViewModelState.maxTargets,
            locale: locale
        )

        let cellsViewModel = createCellsViewModel(
            from: parachainViewModelState.selectedValidatorList,
            locale: locale
        )

        return SelectedValidatorListViewModel(
            headerViewModel: headerViewModel,
            cellViewModels: cellsViewModel,
            limitIsExceeded: parachainViewModelState.selectedValidatorList.count > parachainViewModelState.maxTargets,
            selectedValidatorsLimit: parachainViewModelState.maxTargets
        )
    }
}
