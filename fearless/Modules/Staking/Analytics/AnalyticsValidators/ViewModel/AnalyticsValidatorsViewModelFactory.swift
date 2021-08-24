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
        stashAddress: AccountAddress,
        rewards: [SubqueryRewardItemData],
        nomination: Nomination,
        identitiesByAddress: [AccountAddress: AccountIdentity]?,
        page: AnalyticsValidatorsPage,
        locale: Locale
    ) -> AnalyticsValidatorsViewModel {
        percentFormatter.locale = locale

        let totalEras = totalErasCount(eraValidatorInfos: eraValidatorInfos)
        let totalRewards = totalRewardOfStash(address: stashAddress, rewards: rewards)
        let distinctValidators = Set<String>(eraValidatorInfos.map(\.address))

        let validatorsWhoOwnedStake: [AnalyticsValidatorItemViewModel] = distinctValidators.map { address in
            let icon = try? iconGenerator.generateFromAddress(address)
            let validatorName = (identitiesByAddress?[address]?.displayName) ?? address
            let (progressPercents, amount, progressText): (Double, Double, String) = {
                switch page {
                case .activity:
                    let infos = eraValidatorInfos.filter { $0.address == address }
                    let distinctEras = Set<EraIndex>(infos.map(\.era))
                    let distinctErasCount = distinctEras.count

                    let percents = Double(distinctErasCount) / Double(totalEras)
                    let text = activityProgressDescription(percents: percents, erasCount: distinctErasCount)
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

            return .init(
                icon: icon,
                validatorName: validatorName,
                amount: amount,
                progressPercents: progressPercents,
                progressText: progressText,
                validatorAddress: address
            )
        }
        .sorted(by: { $0.amount > $1.amount })

        let validatorsWhoDontOwnStake = findValidatorsWhoDontOwnStake(
            page: page,
            nomination: nomination,
            distinctValidators: distinctValidators,
            identitiesByAddress: identitiesByAddress,
            locale: locale
        )

        let listTitle = determineListTitle(page: page, locale: locale)
        let chartCenterText = createChartCenterText(
            page: page,
            validators: validatorsWhoOwnedStake,
            totalEras: totalEras,
            locale: locale
        )

        let amounts = validatorsWhoOwnedStake.map(\.progressPercents)
        let inactiveSegmentValue = findInactiveSegmentValue(
            page: page,
            eraValidatorInfos: eraValidatorInfos,
            totalEras: totalEras
        )

        return AnalyticsValidatorsViewModel(
            pieChartSegmentValues: amounts,
            pieChartInactiveSegmentValue: inactiveSegmentValue,
            chartCenterText: chartCenterText,
            listTitle: listTitle,
            validators: validatorsWhoOwnedStake + validatorsWhoDontOwnStake,
            selectedPage: page
        )
    }

    private func activityProgressDescription(percents: Double, erasCount: Int) -> String {
        let percentsString = percentFormatter.string(from: percents as NSNumber) ?? ""
        return percentsString + " (\(erasCount) eras)"
    }

    private func findValidatorsWhoDontOwnStake(
        page: AnalyticsValidatorsPage,
        nomination: Nomination,
        distinctValidators: Set<String>,
        identitiesByAddress: [AccountAddress: AccountIdentity]?,
        locale: Locale
    ) -> [AnalyticsValidatorItemViewModel] {
        let addressFactory = SS58AddressFactory()
        let progressText: String = {
            switch page {
            case .activity:
                return activityProgressDescription(percents: 0, erasCount: 0)
            case .rewards:
                return balanceViewModelFactory.amountFromValue(0).value(for: locale)
            }
        }()
        return nomination
            .targets
            .compactMap { validatorId in
                let validatorAddress = try? addressFactory.addressFromAccountId(
                    data: validatorId,
                    type: self.chain.addressType
                )
                guard
                    let address = validatorAddress,
                    !distinctValidators.contains(address)
                else { return nil }

                let icon = try? self.iconGenerator.generateFromAddress(address)
                let validatorName = (identitiesByAddress?[address]?.displayName) ?? address
                return AnalyticsValidatorItemViewModel(
                    icon: icon,
                    validatorName: validatorName,
                    amount: 0,
                    progressPercents: 0,
                    progressText: progressText,
                    validatorAddress: address
                )
            }
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
        locale: Locale
    ) -> NSAttributedString {
        switch page {
        case .activity:
            let maxDistinctErasCount = validators.map(\.amount).max() ?? 0
            let activeStakingErasPercents = Double(maxDistinctErasCount) / Double(totalEras)
            let percentageString = percentFormatter.string(from: activeStakingErasPercents as NSNumber) ?? ""

            return createChartCenterText(
                firstLine: R.string.localizable
                    .stakingAnalyticsActiveStaking(preferredLanguages: locale.rLanguages).uppercased(),
                secondLine: percentageString,
                thirdLine: String(
                    format: R.string.localizable.stakingAnalyticsErasRange(
                        Int(maxDistinctErasCount).description,
                        totalEras.description,
                        preferredLanguages: locale.rLanguages
                    )
                ),
                locale: locale
            )
        case .rewards:
            let totalRewards = validators.map(\.amount).reduce(0.0, +)
            let totalRewardsText = balanceViewModelFactory.amountFromValue(Decimal(totalRewards))
                .value(for: locale)
            return createChartCenterText(
                firstLine: R.string.localizable.stakingAnalyticsReceivedRewards(preferredLanguages: locale.rLanguages),
                secondLine: totalRewardsText,
                thirdLine: "100%",
                locale: locale
            )
        }
    }

    private func createChartCenterText(
        firstLine: String,
        secondLine: String,
        thirdLine: String,
        locale _: Locale
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = NSTextAlignment.center

        let activeStakingText = NSAttributedString(
            string: firstLine,
            attributes: [
                NSAttributedString.Key.foregroundColor: R.color.colorAccent()!,
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

    func totalErasCount(eraValidatorInfos: [SubqueryEraValidatorInfo]) -> Int {
        let distinctEras = Set<EraIndex>(eraValidatorInfos.map(\.era))
        return distinctEras.count
    }

    func totalRewardOfStash(
        address: AccountAddress,
        rewards: [SubqueryRewardItemData]
    ) -> Double {
        let rewardsOfStash = rewards.filter { $0.stashAddress == address }
        let totalAmount = rewardsOfStash.reduce(Decimal(0)) { amount, info in
            let decimal = Decimal.fromSubstrateAmount(
                info.amount,
                precision: self.chain.addressType.precision
            )
            return amount + (decimal ?? 0.0)
        }
        return NSDecimalNumber(decimal: totalAmount).doubleValue
    }

    private func findInactiveSegmentValue(
        page: AnalyticsValidatorsPage,
        eraValidatorInfos: [SubqueryEraValidatorInfo],
        totalEras: Int
    ) -> Double? {
        guard case .activity = page else {
            return nil
        }
        let erasRange: Range<EraIndex> = {
            let eras = eraValidatorInfos.map(\.era)
            return (eras.min() ?? 0) ..< (eras.max() ?? 0)
        }()
        let setOfEras: Set<EraIndex> = Set(erasRange)

        let inactiveErasCount = totalEras - setOfEras.count
        return Double(inactiveErasCount) / Double(setOfEras.count)
    }
}
