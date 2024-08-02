import Foundation
import UIKit
import SSFModels

enum StakingPoolStartViewModelFactoryError: Error {
    case numberFormatterPercentError
}

protocol StakingPoolStartViewModelFactoryProtocol {
    func buildViewModel(
        rewardsDelay: TimeInterval?,
        apr: Decimal?,
        unstakePeriod: TimeInterval?,
        rewardsFreq: TimeInterval?,
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
        rewardsDelay: TimeInterval?,
        locale: Locale
    ) -> DetailsTriangularedAttributedViewModel? {
        guard let rewardsDelay = rewardsDelay else {
            return nil
        }

        let timeString = rewardsDelay.readableValue(locale: locale)

        let title = R.string.localizable.stakingPoolRewardsDelayText(
            timeString,
            preferredLanguages: locale.rLanguages
        )
        let nsTitle = title as NSString

        let range = nsTitle.range(of: timeString)

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
        apr: Decimal?,
        locale: Locale
    ) -> DetailsTriangularedAttributedViewModel? {
        let image = R.image.iconDollar()!
        guard let apr = apr else {
            return DetailsTriangularedAttributedViewModel(icon: image, title: nil)
        }

        let formatter = NumberFormatter.percent
        formatter.locale = locale
        guard let percentString = formatter.stringFromDecimal(apr) else {
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

        return DetailsTriangularedAttributedViewModel(icon: image, title: attributedTitle)
    }

    private func buildUnstakeViewModel(
        unstakePeriod: TimeInterval?,
        locale: Locale
    ) -> DetailsTriangularedAttributedViewModel? {
        guard let unstakePeriod = unstakePeriod else {
            return nil
        }

        let timeString = unstakePeriod.readableValue(locale: locale)
        let title = R.string.localizable.stakingPoolStartUnstakePeriodText(
            timeString,
            preferredLanguages: locale.rLanguages
        )

        let nsTitle = title as NSString
        let range = nsTitle.range(of: timeString)

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
        rewardsFreq: TimeInterval?,
        locale: Locale
    ) -> DetailsTriangularedAttributedViewModel? {
        guard let rewardsFreq = rewardsFreq else {
            return nil
        }

        let timeString = rewardsFreq.readableValue(locale: locale)
        let title = R.string.localizable.stakingPoolStartRewardFreqText(
            timeString,
            preferredLanguages: locale.rLanguages
        )

        let nsTitle = title as NSString
        let range = nsTitle.range(of: timeString)

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
        rewardsDelay: TimeInterval?,
        apr: Decimal?,
        unstakePeriod: TimeInterval?,
        rewardsFreq: TimeInterval?,
        locale: Locale
    ) -> StakingPoolStartViewModel {
        let description = buildDescriptionText(locale: locale)
        let delayDetailsViewModel = buildRewardsDelayViewModel(
            rewardsDelay: rewardsDelay,
            locale: locale
        )
        let estimatedRewardViewModel = buildEstimatedRewardViewModel(
            apr: apr,
            locale: locale
        )
        let unstakePeriodViewModel = buildUnstakeViewModel(
            unstakePeriod: unstakePeriod,
            locale: locale
        )
        let rewardsFreqViewModel = buildRewardFreqViewModel(
            rewardsFreq: rewardsFreq,
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
