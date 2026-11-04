import Foundation
import BigInt

/// Estimates future nominator returns from the last completed era's actual reward allocation.
/// Validator self-stake incentives are excluded: they are not distributed to nominators.
struct AssetHubRewardCalculatorEngine: RewardCalculatorEngineProtocol {
    let rewardAssetRate: Decimal = 1
    let dailyReturns: [AccountId: Decimal]
    let eraDuration: TimeInterval

    init(reward: BigUInt, points: EraRewardPoints, validators: [EraValidatorInfo], eraDuration: TimeInterval) throws {
        guard points.total > 0, eraDuration > 0, eraDuration.isFinite, !validators.isEmpty,
              Set(points.individual.map(\.accountId)).count == points.individual.count,
              points.individual.reduce(UInt64(0), { $0 + UInt64($1.rewardPoint) }) == UInt64(points.total),
              let pool = Decimal(string: reward.description) else {
            throw EraValidatorServiceError.unexpectedInfo
        }
        self.eraDuration = eraDuration
        let shares = Dictionary(uniqueKeysWithValues: points.individual.map { ($0.accountId, $0.rewardPoint) })
        dailyReturns = try validators.reduce(into: [:]) { result, validator in
            guard let stake = Decimal(string: validator.exposure.total.description),
                  let commission = Decimal.fromSubstratePerbill(value: validator.prefs.commission),
                  commission >= 0, commission <= 1, result[validator.accountId] == nil else {
                throw EraValidatorServiceError.unexpectedInfo
            }
            // Multiply before division so a recurring points fraction does not lose
            // precision before it is scaled by the actual reward allocation.
            let allocation = pool * Decimal(shares[validator.accountId, default: 0]) * (1 - commission)
            result[validator.accountId] = stake > 0
                ? allocation / (Decimal(points.total) * stake) * Decimal(86400 / eraDuration) : 0
        }
    }

    func calculateEarnings(amount: Decimal, validatorAccountId: AccountId, isCompound: Bool, period: CalculationPeriod) throws -> Decimal {
        guard let rate = dailyReturns[validatorAccountId] else {
            throw RewardCalculatorEngineError.unexpectedValidator(accountId: validatorAccountId)
        }
        return earnings(amount: amount, dailyReturn: rate, isCompound: isCompound, period: period)
    }

    func calculateMaxEarnings(amount: Decimal, isCompound: Bool, period: CalculationPeriod) -> Decimal {
        earnings(amount: amount, dailyReturn: dailyReturns.values.max() ?? 0, isCompound: isCompound, period: period)
    }

    func calculateAvgEarnings(amount: Decimal, isCompound: Bool, period: CalculationPeriod) -> Decimal {
        guard !dailyReturns.isEmpty else { return 0 }
        let average = dailyReturns.values.reduce(0, +) / Decimal(dailyReturns.count)
        return earnings(amount: amount, dailyReturn: average, isCompound: isCompound, period: period)
    }

    func calculatorReturn(isCompound: Bool, period: CalculationPeriod, type: RewardReturnType) -> Decimal {
        switch type {
        case let .max(account?):
            return (try? calculateEarnings(amount: 1, validatorAccountId: account, isCompound: isCompound, period: period)) ?? 0
        case .max(nil):
            return calculateMaxEarnings(amount: 1, isCompound: isCompound, period: period)
        case .avg:
            return calculateAvgEarnings(amount: 1, isCompound: isCompound, period: period)
        }
    }

    func maxEarningsTitle(locale: Locale) -> String {
        R.string.localizable.stakingRewardInfoMax(preferredLanguages: locale.rLanguages)
    }

    func avgEarningTitle(locale: Locale) -> String {
        R.string.localizable.stakingRewardInfoAvg(preferredLanguages: locale.rLanguages)
    }

    private func earnings(amount: Decimal, dailyReturn: Decimal, isCompound: Bool, period: CalculationPeriod) -> Decimal {
        guard amount > 0, period.inDays > 0 else { return 0 }
        if !isCompound { return amount * dailyReturn * Decimal(period.inDays) }
        let periods = Double(period.inDays) * 86400 / eraDuration
        let rate = NSDecimalNumber(decimal: dailyReturn).doubleValue * eraDuration / 86400
        let compounded = Foundation.pow(1 + rate, periods) - 1
        guard compounded.isFinite else { return 0 }
        return amount * Decimal(compounded)
    }
}
