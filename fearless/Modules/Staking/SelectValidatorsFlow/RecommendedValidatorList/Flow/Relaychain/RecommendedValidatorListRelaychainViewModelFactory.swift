import Foundation
import SoraFoundation
import FearlessUtils

class RecommendedValidatorListRelaychainViewModelFactory {
    private let iconGenerator: IconGenerating
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol

    init(
        iconGenerator: IconGenerating,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol
    ) {
        self.iconGenerator = iconGenerator
        self.balanceViewModelFactory = balanceViewModelFactory
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
    func buildViewModel(viewModelState: RecommendedValidatorListViewModelState, locale: Locale) -> RecommendedValidatorListViewModel? {
        guard let relaychainViewModelState = viewModelState as? RecommendedValidatorListRelaychainViewModelState else {
            return nil
        }

        let apyFormatter = NumberFormatter.percent.localizableResource().value(for: locale)

        let items: [LocalizableResource<RecommendedValidatorViewModelProtocol>] =
            relaychainViewModelState.validators.compactMap { validator in
                guard let icon = try? iconGenerator.generateFromAddress(validator.address) else {
                    return nil
                }

                let title = validator.identity?.displayName ?? validator.address

                let apy: NSAttributedString? = validator.stakeInfo.map { info in
                    let stakeReturnString = apyFormatter.stringFromDecimal(info.stakeReturn) ?? ""
                    let apyString = "APY \(stakeReturnString)"

                    let apyStringAttributed = NSMutableAttributedString(string: apyString)
                    apyStringAttributed.addAttribute(
                        .foregroundColor,
                        value: R.color.colorColdGreen() as Any,
                        range: (apyString as NSString).range(of: stakeReturnString)
                    )
                    return apyStringAttributed
                }

                let balanceViewModel = balanceViewModelFactory.balanceFromPrice(
                    validator.totalStake,
                    priceData: nil
                ).value(for: locale)

                let stakedString = R.string.localizable.yourValidatorsValidatorTotalStake(
                    "\(balanceViewModel.amount)",
                    preferredLanguages: locale.rLanguages
                )

                return LocalizableResource { _ in
                    RecommendedValidatorViewModel(
                        icon: icon,
                        title: title,
                        details: apy,
                        detailsAux: stakedString,
                        isSelected: false
                    )
                }
            }

        let itemsCountString = createItemsCountString(for: items.count, outOf: relaychainViewModelState.maxTargets)

        return RecommendedValidatorListViewModel(
            itemsCountString: itemsCountString,
            itemViewModels: items,
            title: R.string.localizable
                .stakingRecommendedSectionTitle(preferredLanguages: locale.rLanguages),
            continueButtonEnabled: true,
            rewardColumnTitle: R.string.localizable.stakingFilterTitleRewards(preferredLanguages: locale.rLanguages),
            continueButtonTitle: R.string.localizable.commonContinue(preferredLanguages: locale.rLanguages)
        )
    }
}
