import Foundation
import SoraFoundation
import FearlessUtils

class RecommendedValidatorListParachainViewModelFactory {
    private let iconGenerator: IconGenerating

    init(
        iconGenerator: IconGenerating
    ) {
        self.iconGenerator = iconGenerator
    }

    private func createStakeReturnString(from stakeReturn: Decimal?) -> LocalizableResource<String> {
        LocalizableResource { locale in
            guard let stakeReturn = stakeReturn else { return "" }

            let percentageFormatter = NumberFormatter.percent.localizableResource().value(for: locale)

            return percentageFormatter.string(from: stakeReturn as NSNumber) ?? ""
        }
    }

    private func createItemsCountString(for currentCount: Int, outOf maxCount: Int) -> LocalizableResource<String> {
        LocalizableResource { locale in
            R.string.localizable.stakingSelectedValidatorsCount_v191(
                currentCount,
                maxCount,
                preferredLanguages: locale.rLanguages
            )
        }
    }
}

extension RecommendedValidatorListParachainViewModelFactory: RecommendedValidatorListViewModelFactoryProtocol {
    func buildViewModel(viewModelState: RecommendedValidatorListViewModelState) -> RecommendedValidatorListViewModel? {
        guard let parachainViewModelState = viewModelState as? RecommendedValidatorListParachainViewModelState else {
            return nil
        }

        let items: [LocalizableResource<RecommendedValidatorViewModelProtocol>] =
            parachainViewModelState.collators.compactMap { collator in
                let icon = try? iconGenerator.generateFromAddress(collator.address)
                let title = collator.identity?.displayName ?? collator.address

                // TODO: stake return real value
                let details = createStakeReturnString(from: Decimal.zero)

                return LocalizableResource { locale in
                    RecommendedValidatorViewModel(
                        icon: icon,
                        title: title,
                        details: details.value(for: locale), isSelected: parachainViewModelState.selectedCollators.contains(collator)
                    )
                }
            }

        let itemsCountString = createItemsCountString(for: items.count, outOf: parachainViewModelState.maxTargets)

        return RecommendedValidatorListViewModel(
            itemsCountString: itemsCountString,
            itemViewModels: items
        )
    }
}
