import Foundation
import RobinHood
import BigInt
import IrohaCrypto
import SSFModels

// For all the cases we suggest that parachains are disabled
// Thus, i_ideal = 0.1 and x_ideal = 0.75
final class SoraRewardCalculatorEngine: RewardCalculatorEngineProtocol {
    let rewardAssetRate: Decimal

    private let dayDurationInSeconds: TimeInterval = 60 * 60 * 24
    private let totalStakeByEra: [EraIndex: BigUInt]
    private let rewardPointsByEra: [EraIndex: EraRewardPoints]
    private let validatorRewardsByEra: [EraIndex: BigUInt]
    private var validators: [EraValidatorInfo] = []
    private let eraDurationInSeconds: TimeInterval
    private let chainAsset: ChainAsset

    private lazy var erasPerDay: Decimal = {
        Decimal(dayDurationInSeconds / eraDurationInSeconds)
    }()

    init(
        totalStakeByEra: [EraIndex: BigUInt],
        rewardPointsByEra: [EraIndex: EraRewardPoints],
        validatorRewardsByEra: [EraIndex: BigUInt],
        validators: [EraValidatorInfo],
        chainAsset: ChainAsset,
        eraDurationInSeconds: TimeInterval,
        rewardAssetRate: Decimal = RewardCalculatorConstants.defaultRewardAssetRate
    ) {
        self.totalStakeByEra = totalStakeByEra
        self.validatorRewardsByEra = validatorRewardsByEra
        self.rewardPointsByEra = rewardPointsByEra
        self.validators = validators
        self.eraDurationInSeconds = eraDurationInSeconds
        self.rewardAssetRate = rewardAssetRate
        self.chainAsset = chainAsset
    }

    func avgEarningTitle(locale: Locale) -> String {
        R.string.localizable.stakingRewardInfoAvg(preferredLanguages: locale.rLanguages)
    }

    func maxEarningsTitle(locale: Locale) -> String {
        R.string.localizable.stakingRewardInfoMax(preferredLanguages: locale.rLanguages)
    }

    func calculateEarnings(
        amount _: Decimal,
        validatorAccountId: AccountId,
        isCompound _: Bool,
        period: CalculationPeriod
    ) throws -> Decimal {
        guard let validator = validators.first(where: { $0.accountId == validatorAccountId }) else {
            throw ReefRewardCalculatorEngineError.validatorNotFound(accountId: validatorAccountId)
        }

        let avgIndividualRewardPoint = rewardPointsByEra
            .compactMap { $0.value.individual }
            .reduce([], +)
            .filter { $0.accountId == validatorAccountId }
            .compactMap { $0.rewardPoint }
            .average()
        let eraRewardPointsTotal = rewardPointsByEra.compactMap { $0.value.total }.average()

        let validatorOwnStake = Decimal.fromSubstrateAmount(validator.exposure.total, precision: Int16(chainAsset.asset.precision)).or(.zero)

        let portion = Decimal(avgIndividualRewardPoint) / Decimal(eraRewardPointsTotal)
        let averageValidatorPayout = validatorRewardsByEra.compactMap { $0.value }.average()
        let averageValidatorPayoutDecimal = Decimal.fromSubstrateAmount(averageValidatorPayout, precision: Int16(chainAsset.asset.precision)).or(.zero)
        let averageValidatorRewardInVal = averageValidatorPayoutDecimal * portion
        let ownStakeInVal = validatorOwnStake * rewardAssetRate

        let comissionDecimal = Decimal.fromSubstratePerbill(value: validator.prefs.commission).or(0)
        let result = averageValidatorRewardInVal / ownStakeInVal * (1 - comissionDecimal)

        return result * erasPerDay * Decimal(period.inDays)
    }

    func calculateMaxEarnings(
        amount: Decimal,
        isCompound: Bool,
        period: CalculationPeriod
    ) -> Decimal {
        do {
            let electedValidators = validators.filter { $0.exposure.total > 0 }
            let validatorsEarnings = try electedValidators.compactMap { try calculateEarnings(amount: amount, validatorAccountId: $0.accountId, isCompound: isCompound, period: period) }
            return validatorsEarnings.max() ?? .zero
        } catch {
            return .zero
        }
    }

    func calculateAvgEarnings(
        amount: Decimal,
        isCompound: Bool,
        period: CalculationPeriod
    ) -> Decimal {
        do {
            let electedValidators = validators.filter { $0.exposure.total > 0 }
            let validatorsEarnings = try electedValidators.compactMap { try calculateEarnings(amount: amount, validatorAccountId: $0.accountId, isCompound: isCompound, period: period) }

            return validatorsEarnings.sum() / Decimal(electedValidators.count)
        } catch {
            return .zero
        }
    }

    func calculatorReturn(
        isCompound: Bool,
        period: CalculationPeriod,
        type: RewardReturnType
    ) -> Decimal {
        switch type {
        case let .max(validatorId):
            if let validatorId = validatorId {
                return (try? calculateValidatorReturn(validatorAccountId: validatorId, isCompound: isCompound, period: period)) ?? .zero
            } else {
                return calculateMaxEarnings(amount: 1.0, isCompound: isCompound, period: period)
            }
        case .avg:
            return calculateAvgEarnings(amount: 1.0, isCompound: isCompound, period: period)
        }
    }
}
