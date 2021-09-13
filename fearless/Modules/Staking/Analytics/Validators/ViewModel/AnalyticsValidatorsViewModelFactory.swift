import SoraFoundation
import FearlessUtils
import BigInt
import IrohaCrypto

final class AnalyticsValidatorsViewModelFactory: AnalyticsValidatorsViewModelFactoryProtocol {
    private lazy var iconGenerator = PolkadotIconGenerator()

    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let chain: Chain
    private let percentFormatter = NumberFormatter.percent

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chain: Chain
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chain = chain
    }

    func createViewModel(
        eraValidatorInfos: [SubqueryEraValidatorInfo],
        eraRange: EraRange,
        stashAddress: AccountAddress,
        rewards: [SubqueryRewardItemData],
        nomination: Nomination,
        identitiesByAddress: [AccountAddress: AccountIdentity]?,
        page: AnalyticsValidatorsPage,
        locale: Locale
    ) -> AnalyticsValidatorsViewModel {
        percentFormatter.locale = locale

        let totalEras = Int(eraRange.end - eraRange.start + 1)
        let erasWhenStaked = countErasWhenStaked(eraValidatorInfos: eraValidatorInfos)
        let totalRewards = totalRewardOfStash(address: stashAddress, rewards: rewards)
        let addressFactory = SS58AddressFactory()
        let validatorsAddresses = nomination.targets.compactMap { accountId in
            try? addressFactory.address(fromAccountId: accountId, type: UInt16(chain.addressType.rawValue))
        }

        let validatorsViewModel: [AnalyticsValidatorItemViewModel] = validatorsAddresses.map { address in
            let icon = try? iconGenerator.generateFromAddress(address)
            let validatorName = (identitiesByAddress?[address]?.displayName) ?? address
            let (progressPercents, amount, progressText): (Double, Double, String) = {
                switch page {
                case .activity:
                    let infos = eraValidatorInfos.filter { $0.address == address }
                    let distinctEras = Set<EraIndex>(infos.map(\.era))
                    let distinctErasCount = distinctEras.count

                    let percents = Double(distinctErasCount) / Double(totalEras)
                    let text = activityProgressDescription(
                        percents: percents,
                        erasCount: distinctErasCount,
                        locale: locale
                    )
                    return (percents, Double(distinctErasCount), text)
                case .rewards:
                    let rewardsOfValidator = rewards.filter { reward in
                        reward.stashAddress == stashAddress && reward.validatorAddress == address
                    }
                    let totalAmount = rewardsOfValidator.reduce(Decimal(0)) { amount, info in
                        let decimal = Decimal.fromSubstrateAmount(
                            info.amount,
                            precision: chain.addressType.precision
                        )
                        return amount + (decimal ?? 0.0)
                    }
                    let totalAmountText = balanceViewModelFactory
                        .amountFromValue(totalAmount).value(for: locale)
                    let amountDouble = NSDecimalNumber(decimal: totalAmount).doubleValue
                    let percents = amountDouble / totalRewards
                    return (percents, amountDouble, totalAmountText)
                }
            }()

            let secondaryValueText: String = {
                switch page {
                case .activity:
                    return R.string.localizable
                        .stakingAnalyticsValidatorsErasCounter(
                            format: Int(amount),
                            preferredLanguages: locale.rLanguages
                        )
                case .rewards:
                    return percentFormatter.string(from: progressPercents as NSNumber) ?? ""
                }
            }()

            let mainValueText: String = {
                switch page {
                case .activity:
                    return percentFormatter.string(from: progressPercents as NSNumber) ?? ""
                case .rewards:
                    return progressText
                }
            }()

            return .init(
                icon: icon,
                validatorName: validatorName,
                amount: amount,
                progressPercents: progressPercents,
                mainValueText: mainValueText,
                secondaryValueText: secondaryValueText,
                progressFullDescription: progressText,
                validatorAddress: address
            )
        }
        .sorted(by: { $0.amount > $1.amount })

        let listTitle = determineListTitle(page: page, locale: locale)
        let chartCenterText = createChartCenterText(
            page: page,
            validators: validatorsViewModel,
            totalEras: totalEras,
            erasWhenStaked: erasWhenStaked,
            locale: locale
        )

        let amounts = validatorsViewModel.map(\.progressPercents)
        let pieChartInactiveSegment = findInactiveSegment(
            page: page,
            totalEras: totalEras,
            erasWhenStaked: erasWhenStaked
        )

        return AnalyticsValidatorsViewModel(
            pieChartSegmentValues: amounts,
            pieChartInactiveSegment: pieChartInactiveSegment,
            chartCenterText: chartCenterText,
            listTitle: listTitle,
            validators: validatorsViewModel,
            selectedPage: page
        )
    }

    private func activityProgressDescription(percents: Double, erasCount: Int, locale: Locale) -> String {
        let percentsString = percentFormatter.string(from: percents as NSNumber) ?? ""
        let erasString = R.string.localizable
            .stakingAnalyticsValidatorsErasCounter(format: erasCount, preferredLanguages: locale.rLanguages)
        return percentsString + " (\(erasString))"
    }

    private func determineListTitle(page: AnalyticsValidatorsPage, locale: Locale) -> String {
        switch page {
        case .activity:
            return R.string.localizable.stakingAnalyticsStakeAllocation(preferredLanguages: locale.rLanguages)
        case .rewards:
            return R.string.localizable.stakingRewardsTitle(preferredLanguages: locale.rLanguages)
        }
    }

    private func createChartCenterText(
        page: AnalyticsValidatorsPage,
        validators: [AnalyticsValidatorItemViewModel],
        totalEras: Int,
        erasWhenStaked: Int,
        locale: Locale
    ) -> NSAttributedString {
        switch page {
        case .activity:
            let activeStakingErasPercents = Double(erasWhenStaked) / Double(totalEras)
            let percentageString = percentFormatter.string(from: activeStakingErasPercents as NSNumber) ?? ""

            return createChartCenterText(
                firstLine: R.string.localizable
                    .stakingAnalyticsActiveStaking(preferredLanguages: locale.rLanguages).uppercased(),
                secondLine: percentageString,
                thirdLine: String(
                    format: R.string.localizable.stakingAnalyticsEraRange(
                        erasWhenStaked,
                        totalEras,
                        preferredLanguages: locale.rLanguages
                    )
                )
            )
        case .rewards:
            let totalRewards = validators.map(\.amount).reduce(0.0, +)
            let totalRewardsText = balanceViewModelFactory.amountFromValue(Decimal(totalRewards))
                .value(for: locale)
            return createChartCenterText(
                firstLine: R.string.localizable.stakingAnalyticsReceivedRewards(preferredLanguages: locale.rLanguages),
                secondLine: totalRewardsText,
                thirdLine: "100%"
            )
        }
    }

    private func createChartCenterText(
        firstLine: String,
        firstLineColor: UIColor = R.color.colorAccent()!,
        secondLine: String,
        thirdLine: String
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = NSTextAlignment.center

        let activeStakingText = NSAttributedString(
            string: firstLine,
            attributes: [
                NSAttributedString.Key.foregroundColor: firstLineColor,
                NSAttributedString.Key.font: UIFont.capsTitle,
                NSAttributedString.Key.paragraphStyle: paragraphStyle
            ]
        )

        let percentsText = NSAttributedString(
            string: secondLine,
            attributes: [
                NSAttributedString.Key.foregroundColor: R.color.colorWhite()!,
                NSAttributedString.Key.font: UIFont.h2Title,
                NSAttributedString.Key.paragraphStyle: paragraphStyle
            ]
        )

        let erasRangeText = NSAttributedString(
            string: thirdLine,
            attributes: [
                NSAttributedString.Key.foregroundColor: R.color.colorLightGray()!,
                NSAttributedString.Key.font: UIFont.h5Title,
                NSAttributedString.Key.paragraphStyle: paragraphStyle
            ]
        )

        let result = NSMutableAttributedString(attributedString: activeStakingText)
        result.append(.init(string: "\n"))
        result.append(percentsText)
        result.append(.init(string: "\n"))
        result.append(erasRangeText)
        return result
    }

    func countErasWhenStaked(eraValidatorInfos: [SubqueryEraValidatorInfo]) -> Int {
        let distinctEras = Set<EraIndex>(eraValidatorInfos.map(\.era))
        return distinctEras.count
    }

    func totalRewardOfStash(
        address: AccountAddress,
        rewards: [SubqueryRewardItemData]
    ) -> Double {
        let rewardsOfStash = rewards.filter { $0.stashAddress == address && $0.isReward }
        let totalAmount = rewardsOfStash.reduce(Decimal(0)) { amount, info in
            let decimal = Decimal.fromSubstrateAmount(
                info.amount,
                precision: self.chain.addressType.precision
            )
            return amount + (decimal ?? 0.0)
        }
        return NSDecimalNumber(decimal: totalAmount).doubleValue
    }

    private func findInactiveSegment(
        page: AnalyticsValidatorsPage,
        totalEras: Int,
        erasWhenStaked: Int
    ) -> AnalyticsValidatorsViewModel.InactiveSegment? {
        guard case .activity = page else {
            return nil
        }
        let activeStakingErasPercents = Double(erasWhenStaked) / Double(totalEras)

        return .init(
            percents: 1.0 - activeStakingErasPercents,
            eraCount: totalEras - erasWhenStaked
        )
    }

    func chartCenterText(validator: AnalyticsValidatorItemViewModel) -> NSAttributedString {
        createChartCenterText(
            firstLine: validator.validatorName,
            firstLineColor: R.color.colorLightGray()!,
            secondLine: validator.mainValueText,
            thirdLine: validator.secondaryValueText
        )
    }

    func chartCenterTextInactiveSegment(
        _ inactiveSegment: AnalyticsValidatorsViewModel.InactiveSegment,
        locale: Locale
    ) -> NSAttributedString {
        let percentageString = percentFormatter.string(from: inactiveSegment.percents as NSNumber) ?? ""

        return createChartCenterText(
            firstLine: R.string.localizable
                .stakingAnalyticsValidatorsInactiveStaking(preferredLanguages: locale.rLanguages),
            firstLineColor: R.color.colorGray()!,
            secondLine: percentageString,
            thirdLine: R.string.localizable
                .stakingAnalyticsValidatorsErasCounter(format: inactiveSegment.eraCount, preferredLanguages: locale.rLanguages)
        )
    }
}
