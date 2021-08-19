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
        eraValidatorInfos: [SQEraValidatorInfo],
        stashAddress: AccountAddress,
        rewards: [SubqueryRewardItemData],
        nomination: Nomination,
        identitiesByAddress: [AccountAddress: AccountIdentity]?,
        page: AnalyticsValidatorsPage
    ) -> LocalizableResource<AnalyticsValidatorsViewModel> {
        LocalizableResource { locale in
            self.percentFormatter.locale = locale

            let totalEras = self.totalErasCount(eraValidatorInfos: eraValidatorInfos)

            let distinctValidators = Set<String>(eraValidatorInfos.map(\.address))

            let validatorsWhoOwnedStake: [AnalyticsValidatorItemViewModel] = distinctValidators.map { address in
                let icon = try? self.iconGenerator.generateFromAddress(address)
                let validatorName = (identitiesByAddress?[address]?.displayName) ?? address
                let (progress, distinctErasCount, progressText): (Double, Int, String) = {
                    switch page {
                    case .activity:
                        let infos = eraValidatorInfos.filter { $0.address == address }
                        let distinctEras = Set<EraIndex>(infos.map(\.era))
                        let distinctErasCount = distinctEras.count

                        let percents = Double(distinctErasCount) / Double(totalEras)
                        let text = self.activityProgressDescription(percents: percents, erasCount: distinctErasCount)
                        return (percents, distinctErasCount, text)
                    case .rewards:
                        let rewardsOfValidator = rewards.filter { reward in
                            reward.stashAddress == stashAddress && reward.validatorAddress == address
                        }
                        let totalAmount = rewardsOfValidator.reduce(Decimal(0)) { amount, info in
                            let decimal = Decimal.fromSubstrateAmount(
                                info.amount,
                                precision: self.chain.addressType.precision
                            )
                            return amount + (decimal ?? 0.0)
                        }
                        let totalAmounText = self.balanceViewModelFactory
                            .amountFromValue(totalAmount).value(for: locale)
                        let double = NSDecimalNumber(decimal: totalAmount).doubleValue
                        return (double, 0, totalAmounText)
                    }
                }()

                return .init(
                    icon: icon,
                    validatorName: validatorName,
                    progress: progress,
                    distinctErasCount: distinctErasCount,
                    progressText: progressText,
                    validatorAddress: address
                )
            }
            .sorted(by: { $0.progress > $1.progress })

            let validatorsWhoDontOwnStake = self.findValidatorsWhoDontOwnStake(
                nomination: nomination,
                distinctValidators: distinctValidators,
                identitiesByAddress: identitiesByAddress
            )

            let amounts = validatorsWhoOwnedStake.map(\.progress)
            let chartData = ChartData(amounts: amounts, xAxisValues: ["a", "b"])
            let listTitle = self.determineListTitle(page: page, locale: locale)
            let chartCenterText = self.createChartCenterText(
                validators: validatorsWhoOwnedStake,
                totalEras: totalEras,
                locale: locale
            )

            return AnalyticsValidatorsViewModel(
                chartData: chartData,
                chartCenterText: chartCenterText,
                listTitle: listTitle,
                validators: validatorsWhoOwnedStake + validatorsWhoDontOwnStake,
                selectedPage: page
            )
        }
    }

    private func activityProgressDescription(percents: Double, erasCount: Int) -> String {
        let percentsString = percentFormatter.string(from: percents as NSNumber) ?? ""
        return percentsString + " (\(erasCount) eras)"
    }

    private func findValidatorsWhoDontOwnStake(
        nomination: Nomination,
        distinctValidators: Set<String>,
        identitiesByAddress: [AccountAddress: AccountIdentity]?
    ) -> [AnalyticsValidatorItemViewModel] {
        let addressFactory = SS58AddressFactory()
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
                    progress: 0,
                    distinctErasCount: 0,
                    progressText: self.activityProgressDescription(percents: 0, erasCount: 0),
                    validatorAddress: address
                )
            }
    }

    private func determineListTitle(page: AnalyticsValidatorsPage, locale _: Locale) -> String {
        switch page {
        case .activity:
            return "stake allocation".uppercased()
        case .rewards:
            return "Rewards".uppercased()
        }
    }

    private func createChartCenterText(
        validators: [AnalyticsValidatorItemViewModel],
        totalEras: Int,
        locale _: Locale
    ) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = NSTextAlignment.center

        let activeStakingText = NSAttributedString(
            string: "Active staking".uppercased(),
            attributes: [
                NSAttributedString.Key.foregroundColor: R.color.colorAccent()!,
                NSAttributedString.Key.font: UIFont.capsTitle,
                NSAttributedString.Key.paragraphStyle: paragraphStyle
            ]
        )

        let maxDistinctErasCount = validators.map(\.distinctErasCount).max() ?? 0
        let activeStakingErasPercents = Double(maxDistinctErasCount) / Double(totalEras)
        let percentageString = percentFormatter.string(from: activeStakingErasPercents as NSNumber) ?? ""
        let percentsText = NSAttributedString(
            string: percentageString,
            attributes: [
                NSAttributedString.Key.foregroundColor: R.color.colorWhite()!,
                NSAttributedString.Key.font: UIFont.h2Title,
                NSAttributedString.Key.paragraphStyle: paragraphStyle
            ]
        )

        let erasRangeText = NSAttributedString(
            string: String(format: "%i of %i eras", maxDistinctErasCount, totalEras),
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

    func totalErasCount(eraValidatorInfos: [SQEraValidatorInfo]) -> Int {
        let distinctEras = Set<EraIndex>(eraValidatorInfos.map(\.era))
        return distinctEras.count
    }
}
