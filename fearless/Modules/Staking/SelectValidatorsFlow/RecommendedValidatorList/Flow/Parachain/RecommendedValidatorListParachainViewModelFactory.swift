import Foundation
import SoraFoundation
import FearlessUtils

// swiftlint:disable type_name
class RecommendedValidatorListParachainViewModelFactory {
    private let iconGenerator: IconGenerating

    init(iconGenerator: IconGenerating) {
        self.iconGenerator = iconGenerator
    }

    private func createStakeReturnString(from stakeReturn: Decimal?) -> LocalizableResource<String> {
        LocalizableResource { locale in
            guard let stakeReturn = stakeReturn else { return "" }

            let percentageFormatter = NumberFormatter.percentPlain.localizableResource().value(for: locale)

            return percentageFormatter.string(from: stakeReturn as NSNumber) ?? ""
        }
    }

    private func createItemsCountString(for count: Int, outOf _: Int) -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.parachainStakingRecommendedListTitle(count, preferredLanguages: locale.rLanguages)
        }
    }
}

extension RecommendedValidatorListParachainViewModelFactory: RecommendedValidatorListViewModelFactoryProtocol {
    func buildViewModel(
        viewModelState: RecommendedValidatorListViewModelState,
        locale: Locale
    ) -> RecommendedValidatorListViewModel? {
        guard let parachainViewModelState = viewModelState as? RecommendedValidatorListParachainViewModelState else {
            return nil
        }

        let items: [LocalizableResource<RecommendedValidatorViewModelProtocol>] =
            parachainViewModelState.collators.compactMap { collator in
                let icon = try? iconGenerator.generateFromAddress(collator.address)
                let title = collator.identity?.displayName ?? collator.address

                let aprDecimal = Decimal(collator.subqueryData?.apr ?? 0)
                let details = createStakeReturnString(from: aprDecimal)

                return LocalizableResource { locale in
                    RecommendedValidatorViewModel(
                        icon: icon,
                        title: title,
                        details: details.value(for: locale),
                        isSelected: parachainViewModelState.selectedCollators.contains(collator)
                    )
                }
            }

        let itemsCountString = createItemsCountString(for: items.count, outOf: parachainViewModelState.maxTargets)

        return RecommendedValidatorListViewModel(
            itemsCountString: itemsCountString,
            itemViewModels: items,
            title: R.string.localizable.parachainStakingRecommendedSectionTitle(preferredLanguages: locale.rLanguages),
            continueButtonEnabled: !parachainViewModelState.selectedCollators.isEmpty,
            rewardColumnTitle: R.string.localizable.stakingFilterTitleRewardsApr(preferredLanguages: locale.rLanguages),
            continueButtonTitle: R.string.localizable.stakingCustomCollatorsTitle(preferredLanguages: locale.rLanguages)
        )
    }
}
