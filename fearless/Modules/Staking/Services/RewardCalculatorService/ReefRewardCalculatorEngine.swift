import Foundation
import BigInt
import SSFModels
import Accelerate

enum ReefRewardCalculatorEngineError: Error {
    case validatorNotFound(accountId: AccountId)
    case noData
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
        isCompound: Bool,
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
        let last14ErasRewardPoints = rewardPointsByEra
            .sorted(by: { $0.key < $1.key })
            .suffix(15)
            .prefix(14)
        let last14ErasValidatorRewards = validatorRewardsByEra
            .sorted(by: { $0.key < $1.key })
            .suffix(15)
            .prefix(14)
        let avgIndividualRewardPoint = last14ErasRewardPoints
            .compactMap { $0.value.individual }
            .reduce([], +)
            .filter { $0.accountId == validatorAccountId }
            .compactMap { Double($0.rewardPoint) }
            .average()

        guard
            let eraRewardPointsTotal = last14ErasRewardPoints.last?.value.total,
            let totalRewards = last14ErasValidatorRewards.last?.value
        else {
            throw ReefRewardCalculatorEngineError.noData
        }
        let participation = Decimal(avgIndividualRewardPoint) / Decimal(eraRewardPointsTotal)
        let totalRewardsDecimal = Decimal.fromSubstrateAmount(totalRewards, precision: Int16(chainAsset.asset.precision)).or(.zero)
        let poolAllocation = totalRewardsDecimal * participation
        let comissionDecimal = Decimal.fromSubstratePerbill(value: validator.prefs.commission).or(0)

        let dailyInterestRate = ((ratio * poolAllocation) - (comissionDecimal * (ratio * poolAllocation))) / amount
        if isCompound {
            return pow(1.0 + dailyInterestRate, period.inDays) - 1.0
        } else {
            return dailyInterestRate * Decimal(period.inDays)
        }
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
            let validatorsEarnings = try electedValidators.compactMap {
                try calculateEarnings(
                    amount: amount,
                    validatorAccountId: $0.accountId,
                    isCompound: isCompound,
                    period: period
                )
            }

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

    func avgEarningTitle(locale: Locale) -> String {
        R.string.localizable.stakingRewardInfoAvg(preferredLanguages: locale.rLanguages)
    }

    func maxEarningsTitle(locale: Locale) -> String {
        R.string.localizable.stakingRewardInfoMax(preferredLanguages: locale.rLanguages)
    }
}
