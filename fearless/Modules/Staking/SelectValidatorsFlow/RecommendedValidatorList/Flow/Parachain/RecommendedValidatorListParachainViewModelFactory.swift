import Foundation
import SoraFoundation
import FearlessUtils
import BigInt

// swiftlint:disable type_name
final class RecommendedValidatorListParachainViewModelFactory {
    private let iconGenerator: IconGenerating
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let chainAsset: ChainAsset

    init(
        iconGenerator: IconGenerating,
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chainAsset: ChainAsset
    ) {
        self.iconGenerator = iconGenerator
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chainAsset = chainAsset
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

        let apyFormatter = NumberFormatter.percent.localizableResource().value(for: locale)

        let items: [LocalizableResource<RecommendedValidatorViewModelProtocol>] =
            parachainViewModelState.collators.compactMap { collator in
                let icon = try? iconGenerator.generateFromAddress(collator.address)
                let title = collator.identity?.displayName ?? collator.address

                let apy: NSAttributedString? = collator.subqueryData.map { info in
                    let stakeReturnString = apyFormatter.stringFromDecimal(Decimal(info.apr)) ?? ""
                    let apyString = "APY \(stakeReturnString)"

                    let apyStringAttributed = NSMutableAttributedString(string: apyString)
                    apyStringAttributed.addAttribute(
                        .foregroundColor,
                        value: R.color.colorColdGreen() as Any,
                        range: (apyString as NSString).range(of: stakeReturnString)
                    )
                    return apyStringAttributed
                }

                let totalStake = Decimal.fromSubstrateAmount(
                    collator.metadata?.totalCounted ?? BigUInt.zero,
                    precision: Int16(chainAsset.asset.precision)
                ) ?? Decimal.zero
                let balanceViewModel = balanceViewModelFactory.balanceFromPrice(
                    totalStake,
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
                        detailsAttributedString: apy,
                        detailsAux: stakedString,
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
