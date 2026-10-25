import SoraFoundation
import SSFUtils
import BigInt
import IrohaCrypto
import SSFModels

// swiftlint:disable:next type_body_length
final class AnalyticsValidatorsViewModelFactory: AnalyticsValidatorsViewModelFactoryProtocol {
    private struct RewardAllocation {
        let amountsByValidator: [AccountAddress: Decimal]
        let totalAmount: Decimal

        static let empty = RewardAllocation(amountsByValidator: [:], totalAmount: .zero)
    }

    private struct ValidatorProgress {
        let percents: Double
        let amount: Double
        let text: String
    }

    private let iconGenerator: IconGenerating
    private let balanceViewModelFactory: BalanceViewModelFactoryProtocol
    private let chain: ChainModel
    private let asset: AssetModel
    private let percentFormatter = NumberFormatter.percent

    init(
        balanceViewModelFactory: BalanceViewModelFactoryProtocol,
        chain: ChainModel,
        asset: AssetModel,
        iconGenerator: IconGenerating
    ) {
        self.balanceViewModelFactory = balanceViewModelFactory
        self.chain = chain
        self.asset = asset
        self.iconGenerator = iconGenerator
    }

    // swiftlint:disable:next function_body_length function_parameter_count
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

        let totalEras = totalEras(in: eraRange)
        let validEraValidatorInfos = eraValidatorInfos.filter {
            $0.era >= eraRange.start && $0.era <= eraRange.end
        }
        let erasWhenStaked = countErasWhenStaked(eraValidatorInfos: validEraValidatorInfos)

        var seenValidatorAddresses = Set<AccountAddress>()
        let validatorsAddresses = nomination.targets.compactMap { accountId in
            guard accountId.count == chain.accountIdLenght else {
                return nil
            }
            return try? AddressFactory.address(for: accountId, chain: chain)
        }.filter { address in
            seenValidatorAddresses.insert(address).inserted
        }
        let rewardAllocation = createRewardAllocation(
            validatorAddresses: validatorsAddresses,
            stashAddress: stashAddress,
            rewards: rewards
        )

        let validatorsViewModel: [AnalyticsValidatorItemViewModel] = validatorsAddresses.map { address in
            let icon = try? iconGenerator.generateFromAddress(address)
            let validatorName = (identitiesByAddress?[address]?.displayName) ?? address
            let progress: ValidatorProgress = {
                switch page {
                case .activity:
                    let infos = validEraValidatorInfos.filter { $0.address == address }
                    let distinctEras = Set<EraIndex>(infos.map(\.era))
                    let distinctErasCount = distinctEras.count

                    let percents = Double(distinctErasCount) / Double(totalEras)
                    let text = activityProgressDescription(
                        percents: percents,
                        erasCount: distinctErasCount,
                        locale: locale
                    )
                    return ValidatorProgress(
                        percents: percents,
                        amount: Double(distinctErasCount),
                        text: text
                    )
                case .rewards:
                    let totalAmount = rewardAllocation.amountsByValidator[address] ?? .zero
                    let totalAmountText = balanceViewModelFactory
                        .amountFromValue(totalAmount, usageCase: .listCrypto).value(for: locale)
                    let amountDouble = finiteDouble(from: totalAmount)
                    let percents = rewardShare(
                        amount: totalAmount,
                        totalAmount: rewardAllocation.totalAmount
                    )
                    return ValidatorProgress(
                        percents: percents,
                        amount: amountDouble,
                        text: totalAmountText
                    )
                }
            }()

            let secondaryValueText: String = {
                switch page {
                case .activity:
                    return R.string.localizable
                        .stakingAnalyticsValidatorsErasCounter(
                            format: Int(progress.amount),
                            preferredLanguages: locale.rLanguages
                        )
                case .rewards:
                    return percentFormatter.string(from: progress.percents as NSNumber) ?? ""
                }
            }()

            let mainValueText: String = {
                switch page {
                case .activity:
                    return percentFormatter.string(from: progress.percents as NSNumber) ?? ""
                case .rewards:
                    return progress.text
                }
            }()

            return .init(
                icon: icon,
                validatorName: validatorName,
                amount: progress.amount,
                progressPercents: progress.percents,
                mainValueText: mainValueText,
                secondaryValueText: secondaryValueText,
                progressFullDescription: progress.text,
                validatorAddress: address
            )
        }
        .sorted(by: { $0.amount > $1.amount })

        let listTitle = determineListTitle(page: page, locale: locale)
        let chartCenterText = createChartCenterText(
            page: page,
            totalEras: totalEras,
            erasWhenStaked: erasWhenStaked,
            totalRewards: rewardAllocation.totalAmount,
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
        totalEras: Int,
        erasWhenStaked: Int,
        totalRewards: Decimal,
        locale: Locale
    ) -> NSAttributedString {
        switch page {
        case .activity:
            let activeStakingErasPercents = Double(erasWhenStaked) / Double(totalEras)
            let percentageString = percentFormatter.string(from: activeStakingErasPercents as NSNumber) ?? ""

            return createChartCenterText(
                firstLine: R.string.localizable
                    .stakingAnalyticsStakingWasActive(preferredLanguages: locale.rLanguages).uppercased(),
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
            let totalRewardsText = balanceViewModelFactory.amountFromValue(totalRewards, usageCase: .listCrypto)
                .value(for: locale)
            let totalPercentage = totalRewards > .zero ? 1.0 : 0.0
            let totalPercentageText = percentFormatter.string(from: totalPercentage as NSNumber) ?? ""

            return createChartCenterText(
                firstLine: R.string.localizable
                    .stakingAnalyticsReceivedRewards(preferredLanguages: locale.rLanguages),
                secondLine: totalRewardsText,
                thirdLine: totalPercentageText
            )
        }
    }

    private func createChartCenterText(
        firstLine: String,
        firstLineColor: UIColor = R.color.colorPink()!,
        secondLine: String,
        thirdLine: String
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = NSTextAlignment.center

        let firstLineText = NSAttributedString(
            string: firstLine,
            attributes: [
                NSAttributedString.Key.foregroundColor: firstLineColor,
                NSAttributedString.Key.font: UIFont.capsTitle,
                NSAttributedString.Key.paragraphStyle: paragraphStyle
            ]
        )

        let secondLineText = NSAttributedString(
            string: secondLine,
            attributes: [
                NSAttributedString.Key.foregroundColor: R.color.colorWhite()!,
                NSAttributedString.Key.font: UIFont.h2Title,
                NSAttributedString.Key.paragraphStyle: paragraphStyle
            ]
        )

        let thirdLineText = NSAttributedString(
            string: thirdLine,
            attributes: [
                NSAttributedString.Key.foregroundColor: R.color.colorLightGray()!,
                NSAttributedString.Key.font: UIFont.h5Title,
                NSAttributedString.Key.paragraphStyle: paragraphStyle
            ]
        )

        let result = NSMutableAttributedString(attributedString: firstLineText)
        result.append(.init(string: "\n"))
        result.append(secondLineText)
        result.append(.init(string: "\n"))
        result.append(thirdLineText)
        return result
    }

    func countErasWhenStaked(eraValidatorInfos: [SubqueryEraValidatorInfo]) -> Int {
        let distinctEras = Set<EraIndex>(eraValidatorInfos.map(\.era))
        return distinctEras.count
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
                .stakingAnalyticsStakingWasInactive(preferredLanguages: locale.rLanguages).uppercased(),
            firstLineColor: R.color.colorGray()!,
            secondLine: percentageString,
            thirdLine: R.string.localizable.stakingAnalyticsValidatorsErasCounter(
                format: inactiveSegment.eraCount,
                preferredLanguages: locale.rLanguages
            )
        )
    }
}

private extension AnalyticsValidatorsViewModelFactory {
    func totalEras(in eraRange: EraRange) -> Int {
        guard eraRange.end >= eraRange.start else {
            return 1
        }

        return Int(UInt64(eraRange.end) - UInt64(eraRange.start) + 1)
    }

    private func createRewardAllocation(
        validatorAddresses: [AccountAddress],
        stashAddress: AccountAddress,
        rewards: [SubqueryRewardItemData]
    ) -> RewardAllocation {
        guard
            let precision = Int16(exactly: asset.precision),
            !validatorAddresses.isEmpty
        else {
            return .empty
        }

        let validatorAddressSet = Set(validatorAddresses)
        var seenEventIds = Set<String>()
        var substrateAmountsByValidator = [AccountAddress: BigUInt]()

        for reward in rewards {
            let eventId = reward.eventId.trimmingCharacters(in: .whitespacesAndNewlines)
            guard
                reward.isReward,
                reward.stashAddress == stashAddress,
                validatorAddressSet.contains(reward.validatorAddress),
                !eventId.isEmpty,
                seenEventIds.insert(eventId).inserted
            else {
                continue
            }

            substrateAmountsByValidator[reward.validatorAddress, default: .zero] += reward.amount
        }

        let totalSubstrateAmount = substrateAmountsByValidator.values.reduce(BigUInt.zero, +)
        guard
            let totalAmount = Decimal.fromSubstrateAmount(totalSubstrateAmount, precision: precision),
            isValidAmount(totalAmount)
        else {
            return .empty
        }

        var amountsByValidator = [AccountAddress: Decimal]()
        for (address, amount) in substrateAmountsByValidator {
            guard
                let decimalAmount = Decimal.fromSubstrateAmount(amount, precision: precision),
                isValidAmount(decimalAmount)
            else {
                return .empty
            }
            amountsByValidator[address] = decimalAmount
        }

        return RewardAllocation(amountsByValidator: amountsByValidator, totalAmount: totalAmount)
    }

    func finiteDouble(from amount: Decimal) -> Double {
        let value = NSDecimalNumber(decimal: amount).doubleValue
        return value.isFinite && value >= 0.0 ? value : 0.0
    }

    func isValidAmount(_ amount: Decimal) -> Bool {
        let value = NSDecimalNumber(decimal: amount).doubleValue
        return value.isFinite && value >= 0.0
    }

    func rewardShare(amount: Decimal, totalAmount: Decimal) -> Double {
        guard totalAmount > .zero else {
            return 0.0
        }

        let value = NSDecimalNumber(decimal: amount)
            .dividing(by: NSDecimalNumber(decimal: totalAmount))
            .doubleValue

        guard value.isFinite else {
            return 0.0
        }

        return min(max(value, 0.0), 1.0)
    }

    // swiftlint:disable:next file_length
}
