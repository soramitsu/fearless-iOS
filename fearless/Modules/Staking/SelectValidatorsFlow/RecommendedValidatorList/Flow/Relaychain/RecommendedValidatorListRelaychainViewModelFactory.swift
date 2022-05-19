import Foundation
import SoraFoundation
import FearlessUtils

class RecommendedValidatorListRelaychainViewModelFactory {
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

extension RecommendedValidatorListRelaychainViewModelFactory: RecommendedValidatorListViewModelFactoryProtocol {
    func buildViewModel(viewModelState: RecommendedValidatorListViewModelState) -> RecommendedValidatorListViewModel? {
        guard let relaychainViewModelState = viewModelState as? RecommendedValidatorListRelaychainViewModelState else {
            return nil
        }

        let items: [LocalizableResource<RecommendedValidatorViewModelProtocol>] =
            relaychainViewModelState.validators.compactMap { validator in
                guard let icon = try? iconGenerator.generateFromAddress(validator.address) else {
                    return nil
                }

                let title = validator.identity?.displayName ?? validator.address

                let details = createStakeReturnString(from: validator.stakeInfo?.stakeReturn)

                return LocalizableResource { locale in
                    RecommendedValidatorViewModel(
                        icon: icon,
                        title: title,
                        details: details.value(for: locale)
                    )
                }
            }

        let itemsCountString = createItemsCountString(for: items.count, outOf: relaychainViewModelState.maxTargets)

        return RecommendedValidatorListViewModel(
            itemsCountString: itemsCountString,
            itemViewModels: items
        )
    }
}
