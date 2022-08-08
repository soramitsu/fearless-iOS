import Foundation
import UIKit

enum StakingPoolStartViewModelFactoryError: Error {
    case numberFormatterPercentError
}

protocol StakingPoolStartViewModelFactoryProtocol {
    func buildViewModel(
        rewardsDelayInDays: Int,
        apr: Decimal,
        unstakePeriodInDays: Int,
        rewardsFreqInDays: Int,
        locale: Locale
    ) -> StakingPoolStartViewModel
}

final class StakingPoolStartViewModelFactory {
    private let chainAsset: ChainAsset

    init(chainAsset: ChainAsset) {
        self.chainAsset = chainAsset
    }

    private func buildDescriptionText(locale: Locale) -> NSAttributedString? {
        let symbolString = chainAsset.asset.symbol.uppercased()
        let title = R.string.localizable.stakingPoolStartEarnRewardTitle(
            symbolString,
            preferredLanguages: locale.rLanguages
        )
        let nsTitle = title as NSString

        let range = nsTitle.range(of: symbolString)

        let attributedTitle = NSMutableAttributedString(string: title)
        attributedTitle.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: R.color.colorPink()!,
            range: range
        )
        attributedTitle.addAttribute(
            NSAttributedString.Key.font,
            value: UIFont.h1Title,
            range: range
        )

        return attributedTitle
    }

    private func buildRewardsDelayViewModel(
        rewardsDelayInDays: Int,
        locale: Locale
    ) -> DetailsTriangularedAttributedViewModel {
        let daysStringValue = R.string.localizable.stakingPoolRewardsDelay(
            format: rewardsDelayInDays,
            preferredLanguages: locale.rLanguages
        )

        let title = R.string.localizable.stakingPoolStartEarnRewardTitle(
            daysStringValue,
            preferredLanguages: locale.rLanguages
        )
        let nsTitle = title as NSString

        let range = nsTitle.range(of: daysStringValue)

        let image = R.image.iconChart()!

        let attributedTitle = NSMutableAttributedString(string: title)
        attributedTitle.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: R.color.colorPink()!,
            range: range
        )

        return DetailsTriangularedAttributedViewModel(icon: image, title: attributedTitle)
    }

    private func buildEstimatedRewardViewModel(
        apr: Decimal,
        locale: Locale
    ) -> DetailsTriangularedAttributedViewModel? {
        guard let percentString = NumberFormatter.percentPlain.stringFromDecimal(apr) else {
            return nil
        }

        let title = R.string.localizable.stakingPoolStartAprText(
            percentString,
            preferredLanguages: locale.rLanguages
        )
        let nsTitle = title as NSString
        let range = nsTitle.range(of: percentString)

        let attributedTitle = NSMutableAttributedString(string: title)
        attributedTitle.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: R.color.colorPink()!,
            range: range
        )

        let image = R.image.iconDollar()!

        return DetailsTriangularedAttributedViewModel(icon: image, title: attributedTitle)
    }

    private func buildUnstakeViewModel(
        unstakePeriod: Int,
        locale: Locale
    ) -> DetailsTriangularedAttributedViewModel {
        let unstakePeriodString = R.string.localizable.stakingPoolUnstakeDelay(
            format: unstakePeriod,
            preferredLanguages: locale.rLanguages
        )
        let title = R.string.localizable.stakingPoolStartUnstakePeriodText(
            unstakePeriodString,
            preferredLanguages: locale.rLanguages
        )

        let nsTitle = title as NSString
        let range = nsTitle.range(of: unstakePeriodString)

        let attributedTitle = NSMutableAttributedString(string: title)
        attributedTitle.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: R.color.colorPink()!,
            range: range
        )

        let image = R.image.iconWithdrawal()!

        return DetailsTriangularedAttributedViewModel(icon: image, title: attributedTitle)
    }

    private func buildRewardFreqViewModel(
        rewardsFreq: Int,
        locale: Locale
    ) -> DetailsTriangularedAttributedViewModel {
        let rewardsFreqString = R.string.localizable.stakingPoolRewardsFreq(
            format: rewardsFreq,
            preferredLanguages: locale.rLanguages
        )
        let daysString = R.string.localizable.commonDaysFormat(
            format: rewardsFreq,
            preferredLanguages: locale.rLanguages
        )
        let title = R.string.localizable.stakingPoolStartRewardFreqText(
            daysString,
            preferredLanguages: locale.rLanguages
        )

        let nsTitle = title as NSString
        let range = nsTitle.range(of: rewardsFreqString)

        let attributedTitle = NSMutableAttributedString(string: title)
        attributedTitle.addAttribute(
            NSAttributedString.Key.foregroundColor,
            value: R.color.colorPink()!,
            range: range
        )

        let image = R.image.iconGift()!

        return DetailsTriangularedAttributedViewModel(icon: image, title: attributedTitle)
    }
}

extension StakingPoolStartViewModelFactory: StakingPoolStartViewModelFactoryProtocol {
    func buildViewModel(
        rewardsDelayInDays: Int,
        apr: Decimal,
        unstakePeriodInDays: Int,
        rewardsFreqInDays: Int,
        locale: Locale
    ) -> StakingPoolStartViewModel {
        let description = buildDescriptionText(locale: locale)
        let delayDetailsViewModel = buildRewardsDelayViewModel(
            rewardsDelayInDays: rewardsDelayInDays,
            locale: locale
        )
        let estimatedRewardViewModel = buildEstimatedRewardViewModel(
            apr: apr,
            locale: locale
        )
        let unstakePeriodViewModel = buildUnstakeViewModel(
            unstakePeriod: unstakePeriodInDays,
            locale: locale
        )
        let rewardsFreqViewModel = buildRewardFreqViewModel(
            rewardsFreq: rewardsFreqInDays,
            locale: locale
        )

        return StakingPoolStartViewModel(
            aboutText: R.string.localizable.poolStakingStartAboutTitle(preferredLanguages: locale.rLanguages),
            descriptionText: description,
            delayDetailsViewModel: delayDetailsViewModel,
            estimatedRewardViewModel: estimatedRewardViewModel,
            unstakePeriodViewModel: unstakePeriodViewModel,
            rewardsFreqViewModel: rewardsFreqViewModel
        )
    }
}
