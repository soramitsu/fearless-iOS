import Foundation
import SoraFoundation
import CommonWallet
import FearlessUtils

protocol CrowdloanContributionViewModelFactoryProtocol {
    func createContributionSetupViewModel(
        from crowdloan: Crowdloan,
        displayInfo: CrowdloanDisplayInfo?,
        metadata: CrowdloanMetadata,
        locale: Locale
    ) -> CrowdloanContributionSetupViewModel

    func createContributionConfirmViewModel(
        from crowdloan: Crowdloan,
        metadata: CrowdloanMetadata,
        confirmationData: CrowdloanContributionConfirmData,
        locale: Locale
    ) throws -> CrowdloanContributeConfirmViewModel

    func createEstimatedRewardViewModel(
        inputAmount: Decimal,
        displayInfo: CrowdloanDisplayInfo,
        locale: Locale
    ) -> String?

    func createAdditionalBonusViewModel(
        inputAmount: Decimal,
        displayInfo: CrowdloanDisplayInfo,
        bonusRate: Decimal?,
        locale: Locale
    ) -> String?

    func createLearnMoreViewModel(
        from displayInfo: CrowdloanDisplayInfo,
        locale: Locale
    ) -> LearnMoreViewModel
}

final class CrowdloanContributionViewModelFactory {
    let chainDateCalculator: ChainDateCalculatorProtocol
    let amountFormatterFactory: AssetBalanceFormatterFactoryProtocol
    let assetInfo: AssetBalanceDisplayInfo

    struct DisplayLeasingPeriod {
        let leasingPeriod: String
        let leasingEndDate: String
    }

    struct DisplayProgress {
        let absoluteProgress: String
        let percentageProgress: String
    }

    private lazy var iconGenerator = PolkadotIconGenerator()

    init(
        assetInfo: AssetBalanceDisplayInfo,
        chainDateCalculator: ChainDateCalculatorProtocol,
        amountFormatterFactory: AssetBalanceFormatterFactoryProtocol = AssetBalanceFormatterFactory()
    ) {
        self.assetInfo = assetInfo
        self.amountFormatterFactory = amountFormatterFactory
        self.chainDateCalculator = chainDateCalculator
    }

    private func createDisplayLeasingPeriod(
        from crowdloan: Crowdloan,
        metadata: CrowdloanMetadata,
        locale: Locale
    ) -> DisplayLeasingPeriod {
        let leasingPeriodTitle: String
        let leasingEndDateTitle: String

        var calendar = Calendar.current
        calendar.locale = locale

        let maybeLeasingTimeInterval = chainDateCalculator.intervalTillPeriod(
            crowdloan.fundInfo.lastPeriod + 1,
            metadata: metadata,
            calendar: calendar
        )

        if let leasingTimeInterval = maybeLeasingTimeInterval {
            if leasingTimeInterval.duration.daysFromSeconds > 0 {
                leasingPeriodTitle = R.string.localizable.commonDaysFormat(
                    format: leasingTimeInterval.duration.daysFromSeconds,
                    preferredLanguages: locale.rLanguages
                )
            } else {
                let time = try? TotalTimeFormatter().string(from: leasingTimeInterval.duration)
                leasingPeriodTitle = time ?? ""
            }

            let dateFormatter = DateFormatter.shortDate.value(for: locale)
            let dateString = dateFormatter.string(from: leasingTimeInterval.tillDate)
            leasingEndDateTitle = R.string.localizable.commonTillDate(dateString, preferredLanguages: locale.rLanguages)

        } else {
            leasingPeriodTitle = ""
            leasingEndDateTitle = ""
        }

        return DisplayLeasingPeriod(leasingPeriod: leasingPeriodTitle, leasingEndDate: leasingEndDateTitle)
    }

    private func createDisplayProgress(
        from crowdloan: Crowdloan,
        metadata _: CrowdloanMetadata,
        locale: Locale
    ) -> DisplayProgress {
        let tokenFormatter = amountFormatterFactory.createTokenFormatter(for: assetInfo).value(for: locale)
        let displayFormatter = amountFormatterFactory.createDisplayFormatter(for: assetInfo).value(for: locale)

        let percentFormatter = NumberFormatter.percentSingle
        percentFormatter.locale = locale

        if
            let raised = Decimal.fromSubstrateAmount(
                crowdloan.fundInfo.raised,
                precision: assetInfo.assetPrecision
            ),
            let cap = Decimal.fromSubstrateAmount(
                crowdloan.fundInfo.cap,
                precision: assetInfo.assetPrecision
            ),
            let raisedString = displayFormatter.stringFromDecimal(raised),
            let totalString = tokenFormatter.stringFromDecimal(cap),
            cap > 0,
            let percentageString = percentFormatter.string(from: (raised / cap) as NSNumber) {
            let absoluteProgress = R.string.localizable.crowdloanRaisedAmount(
                raisedString,
                totalString,
                preferredLanguages: locale.rLanguages
            )

            return DisplayProgress(absoluteProgress: absoluteProgress, percentageProgress: percentageString)
        } else {
            return DisplayProgress(absoluteProgress: "", percentageProgress: "")
        }
    }

    private func createTimeLeft(
        for crowdloan: Crowdloan,
        metadata: CrowdloanMetadata,
        locale: Locale
    ) -> String {
        let remainedTime = crowdloan.remainedTime(
            at: metadata.blockNumber,
            blockDuration: metadata.blockDuration
        )

        if remainedTime.daysFromSeconds > 0 {
            return R.string.localizable.commonDaysFormat(
                format: remainedTime.daysFromSeconds,
                preferredLanguages: locale.rLanguages
            )
        } else {
            let time = try? TotalTimeFormatter().string(from: remainedTime)
            return time ?? ""
        }
    }

    private func createTitle(
        from crowdloan: Crowdloan,
        displayInfo: CrowdloanDisplayInfo?,
        locale: Locale
    ) -> String {
        if let displayInfo = displayInfo {
            return displayInfo.name + "(\(displayInfo.token))"
        } else {
            return NumberFormatter.quantity.localizableResource().value(for: locale).string(
                from: NSNumber(value: crowdloan.paraId)
            ) ?? ""
        }
    }

    private func createLearnMore(
        from displayInfo: CrowdloanDisplayInfo,
        locale: Locale
    ) -> LearnMoreViewModel {
        let iconViewModel: ImageViewModelProtocol? = URL(string: displayInfo.icon).map { RemoteImageViewModel(url: $0)
        }

        let title = R.string.localizable.crowdloanLearn(displayInfo.name, preferredLanguages: locale.rLanguages)
        return LearnMoreViewModel(iconViewModel: iconViewModel, title: title)
    }
}

extension CrowdloanContributionViewModelFactory: CrowdloanContributionViewModelFactoryProtocol {
    func createContributionSetupViewModel(
        from crowdloan: Crowdloan,
        displayInfo: CrowdloanDisplayInfo?,
        metadata: CrowdloanMetadata,
        locale: Locale
    ) -> CrowdloanContributionSetupViewModel {
        let displayLeasingPeriod = createDisplayLeasingPeriod(
            from: crowdloan,
            metadata: metadata,
            locale: locale
        )

        let displayProgress = createDisplayProgress(from: crowdloan, metadata: metadata, locale: locale)

        let remainedTime = createTimeLeft(for: crowdloan, metadata: metadata, locale: locale)

        let title = createTitle(from: crowdloan, displayInfo: displayInfo, locale: locale)

        let learnMoreViewModel = displayInfo.map { createLearnMore(from: $0, locale: locale) }

        return CrowdloanContributionSetupViewModel(
            title: title,
            leasingPeriod: displayLeasingPeriod.leasingPeriod,
            leasingCompletionDate: displayLeasingPeriod.leasingEndDate,
            raisedProgress: displayProgress.absoluteProgress,
            raisedPercentage: displayProgress.percentageProgress,
            remainedTime: remainedTime,
            learnMore: learnMoreViewModel
        )
    }

    func createContributionConfirmViewModel(
        from crowdloan: Crowdloan,
        metadata: CrowdloanMetadata,
        confirmationData: CrowdloanContributionConfirmData,
        locale: Locale
    ) throws -> CrowdloanContributeConfirmViewModel {
        let displayLeasingPeriod = createDisplayLeasingPeriod(
            from: crowdloan,
            metadata: metadata,
            locale: locale
        )

        let senderIcon = try iconGenerator.generateFromAddress(confirmationData.displayAddress.address)
        let senderName = !confirmationData.displayAddress.username.isEmpty ?
            confirmationData.displayAddress.username : confirmationData.displayAddress.address

        let formatter = amountFormatterFactory.createDisplayFormatter(for: assetInfo).value(for: locale)
        let inputAmount = formatter.stringFromDecimal(confirmationData.contribution) ?? ""

        return CrowdloanContributeConfirmViewModel(
            senderIcon: senderIcon,
            senderName: senderName,
            inputAmount: inputAmount,
            leasingPeriod: displayLeasingPeriod.leasingPeriod,
            leasingCompletionDate: displayLeasingPeriod.leasingEndDate
        )
    }

    func createEstimatedRewardViewModel(
        inputAmount: Decimal,
        displayInfo: CrowdloanDisplayInfo,
        locale: Locale
    ) -> String? {
        let tokenInfo = AssetBalanceDisplayInfo.fromCrowdloan(info: displayInfo)
        let formatter = amountFormatterFactory.createTokenFormatter(for: tokenInfo).value(for: locale)

        if let rewardRate = displayInfo.rewardRate {
            return formatter.stringFromDecimal(inputAmount * rewardRate)
        } else {
            return nil
        }
    }

    func createAdditionalBonusViewModel(
        inputAmount: Decimal,
        displayInfo: CrowdloanDisplayInfo,
        bonusRate: Decimal?,
        locale: Locale
    ) -> String? {
        guard let bonusRate = bonusRate else {
            return R.string.localizable.crowdloanEmptyBonusTitle(
                preferredLanguages: locale.rLanguages
            )
        }

        let tokenInfo = AssetBalanceDisplayInfo.fromCrowdloan(info: displayInfo)
        let formatter = amountFormatterFactory.createTokenFormatter(for: tokenInfo).value(for: locale)

        if let rewardRate = displayInfo.rewardRate {
            return formatter.stringFromDecimal(inputAmount * rewardRate * bonusRate)
        } else {
            return nil
        }
    }

    func createLearnMoreViewModel(
        from displayInfo: CrowdloanDisplayInfo,
        locale: Locale
    ) -> LearnMoreViewModel {
        createLearnMore(from: displayInfo, locale: locale)
    }
}
