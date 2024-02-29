import Foundation
import BigInt
import SSFModels
import Accelerate

enum ReefRewardCalculatorEngineError: Error {
    case validatorNotFound(accountId: AccountId)
}

final class ReefRewardCalculatorEngine {
    private let totalStakeByEra: [EraIndex: BigUInt]
    private let rewardPointsByEra: [EraIndex: EraRewardPoints]
    private let validatorRewardsByEra: [EraIndex: BigUInt]
    private let validators: [EraValidatorInfo]
    private let chainAsset: ChainAsset

    init(
        totalStakeByEra: [EraIndex: BigUInt],
        rewardPointsByEra: [EraIndex: EraRewardPoints],
        validatorRewardsByEra: [EraIndex: BigUInt],
        validators: [EraValidatorInfo],
        chainAsset: ChainAsset
    ) {
        self.totalStakeByEra = totalStakeByEra
        self.rewardPointsByEra = rewardPointsByEra
        self.validatorRewardsByEra = validatorRewardsByEra
        self.validators = validators
        self.chainAsset = chainAsset
    }
}

extension ReefRewardCalculatorEngine: RewardCalculatorEngineProtocol {
    var rewardAssetRate: Decimal {
        1.0
    }

    func calculateEarnings(
        amount: Decimal,
        validatorAccountId: AccountId,
        isCompound _: Bool,
        period: CalculationPeriod
    ) throws -> Decimal {
        guard let validator = validators.first(where: { $0.accountId == validatorAccountId }) else {
            throw ReefRewardCalculatorEngineError.validatorNotFound(accountId: validatorAccountId)
        }
        let validatorTotalBonded = Decimal.fromSubstrateAmount(
            validator.exposure.total,
            precision: Int16(chainAsset.asset.precision)
        ).or(.zero)
        let ratio = amount / validatorTotalBonded
        let avgIndividualRewardPoint = rewardPointsByEra
            .sorted(by: { $0.key < $1.key })
            .suffix(14)
            .compactMap { $0.value.individual }
            .reduce([], +)
            .filter { $0.accountId == validatorAccountId }
            .compactMap { $0.rewardPoint }
            .average()
        let eraRewardPointsTotal = (rewardPointsByEra.sorted(by: { $0.key < $1.key }).last?.value.total).or(RewardPoint.min)

//        let participation = rewardPointsByEra.sorted(by: { $0.key < $1.key }).suffix(14).compactMap { Decimal($0.value.individual.first(where: { $0.accountId == validatorAccountId })?.rewardPoint ?? 0) / Decimal($0.value.total ?? 1) }.sum() / 14.0
        let participation = Decimal(avgIndividualRewardPoint) / Decimal(eraRewardPointsTotal)
        let totalRewards = (validatorRewardsByEra.sorted(by: { $0.key < $1.key }).last?.value).or(.zero)
        let totalRewardsDecimal = Decimal.fromSubstrateAmount(totalRewards, precision: Int16(chainAsset.asset.precision)).or(.zero)
        let poolAllocation = totalRewardsDecimal * participation
        let comissionDecimal = Decimal.fromSubstratePerbill(value: validator.prefs.commission).or(0)
        return ((ratio * poolAllocation) - (comissionDecimal * (ratio * poolAllocation))) * Decimal(period.inDays) / amount
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
            return 0.0
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
            return 0.0
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
                return (try? calculateValidatorReturn(validatorAccountId: validatorId, isCompound: isCompound, period: period)) ?? 0.0
            } else {
                return calculateMaxEarnings(amount: 1.0, isCompound: isCompound, period: period)
            }
        case .avg:
            return calculateAvgEarnings(amount: 1.0, isCompound: isCompound, period: period)
        }
    }

    func avgEarningTitle(locale: Locale) -> String {
        R.string.localizable.stakingRewardInfoAvg(preferredLanguages: locale.rLanguages)
    }

    func maxEarningsTitle(locale: Locale) -> String {
        R.string.localizable.stakingRewardInfoMax(preferredLanguages: locale.rLanguages)
    }
}
