import Foundation
import RobinHood
import BigInt
import IrohaCrypto
import SSFModels

// For all the cases we suggest that parachains are disabled
// Thus, i_ideal = 0.1 and x_ideal = 0.75
final class SoraRewardCalculatorEngine: RewardCalculatorEngineProtocol {
    private let dayDurationInSeconds: TimeInterval = 60 * 60 * 24
    private var averageTotalRewardsPerEra: Decimal
    private var validators: [EraValidatorInfo] = []
    private var rewardAssetRate: Decimal
    private let chainId: ChainModel.Id
    private let assetPrecision: Int16
    private let eraDurationInSeconds: TimeInterval

    private lazy var erasPerDay: Decimal = {
        Decimal(dayDurationInSeconds / eraDurationInSeconds)
    }()

    private lazy var totalStake: Decimal = {
        Decimal.fromSubstrateAmount(
            validators.map(\.exposure.total).reduce(0, +),
            precision: assetPrecision
        ) ?? 0.0
    }()

    private var averageStake: Decimal {
        if !validators.isEmpty {
            return totalStake / Decimal(validators.count)
        } else {
            return 0.0
        }
    }

    private lazy var medianCommission: Decimal = {
        let profitable = validators
            .compactMap { Decimal.fromSubstratePerbill(value: $0.prefs.commission) }
            .sorted()
            .filter { $0 < 1.0 }

        guard !profitable.isEmpty else {
            return 0.0
        }

        let commission: Decimal

        let count = profitable.count

        if count % 2 == 0 {
            commission = (profitable[count / 2] + profitable[(count / 2) - 1]) / 2
        } else {
            commission = profitable[(count - 1) / 2]
        }

        return commission
    }()

    private lazy var maxValidator: EraValidatorInfo? = {
        validators.max {
            calculateEarningsForValidator($0, amount: RewardCalculatorConstants.percentCalculationAmount, period: .year, resultType: .percent) <
                calculateEarningsForValidator($1, amount: RewardCalculatorConstants.percentCalculationAmount, period: .year, resultType: .percent)
        }
    }()

    init(
        chainId: ChainModel.Id,
        assetPrecision: Int16,
        averageTotalRewardsPerEra: BigUInt,
        validators: [EraValidatorInfo],
        eraDurationInSeconds: TimeInterval,
        rewardAssetRate: Decimal = RewardCalculatorConstants.defaultRewardAssetRate
    ) {
        self.chainId = chainId
        self.assetPrecision = assetPrecision
        self.averageTotalRewardsPerEra = Decimal.fromSubstrateAmount(
            averageTotalRewardsPerEra,
            precision: assetPrecision
        ) ?? 0.0
        self.validators = validators
        self.eraDurationInSeconds = eraDurationInSeconds
        self.rewardAssetRate = rewardAssetRate
    }

    func avgEarningTitle(locale: Locale) -> String {
        R.string.localizable.stakingRewardInfoAvg(preferredLanguages: locale.rLanguages)
    }

    func maxEarningsTitle(locale: Locale) -> String {
        R.string.localizable.stakingRewardInfoMax(preferredLanguages: locale.rLanguages)
    }

    func calculateEarnings(
        amount: Decimal,
        validatorAccountId: Data,
        isCompound _: Bool,
        period: CalculationPeriod
    ) throws -> Decimal {
        guard let validator = validators.first(where: { $0.accountId == validatorAccountId }) else {
            throw RewardCalculatorEngineError.unexpectedValidator(accountId: validatorAccountId)
        }

        return calculateEarningsForValidator(
            validator,
            amount: amount,
            period: period,
            resultType: .percent
        )
    }

    func calculateMaxEarnings(
        amount: Decimal,
        isCompound _: Bool,
        period: CalculationPeriod
    ) -> Decimal {
        guard let validator = maxValidator else {
            return 0.0
        }

        return calculateEarningsForValidator(
            validator,
            amount: amount,
            period: period,
            resultType: .value
        )
    }

    func calculateAvgEarnings(
        amount: Decimal,
        isCompound _: Bool,
        period: CalculationPeriod
    ) -> Decimal {
        calculateEarningsForAmount(
            amount,
            stake: averageStake,
            commission: medianCommission,
            period: period,
            rewardAssetType: .percent
        )
    }

    func calculatorReturn(isCompound _: Bool, period: CalculationPeriod, type: RewardReturnType) -> Decimal {
        switch type {
        case .max:
            guard let validator = maxValidator else {
                return 0.0
            }

            let commission = Decimal.fromSubstratePerbill(value: validator.prefs.commission) ?? 0.0
            let stake = Decimal.fromSubstrateAmount(
                validator.exposure.total,
                precision: assetPrecision
            ) ?? 0.0

            let eraReturn = calculateReturnForStake(stake, commission: commission)
            let dailyReturn = eraReturn * erasPerDay
            return dailyReturn * Decimal(period.inDays) * rewardAssetRate
        case .avg:
            let commission = validators.compactMap { Decimal.fromSubstratePerbill(value: $0.prefs.commission) ?? 0.0 }.reduce(0,+) / Decimal(validators.count)
            let eraReturn = calculateReturnForStake(averageStake, commission: commission)
            let dailyReturn = eraReturn * erasPerDay
            return dailyReturn * Decimal(period.inDays)
        }
    }

    private func calculateReturnForStake(_ stake: Decimal, commission: Decimal) -> Decimal {
        let portion = stake / totalStake
        let valRewards = (averageTotalRewardsPerEra * portion)
        let stakeValEquivalent = stake * rewardAssetRate
        return valRewards / stakeValEquivalent * (1.0 - commission)
    }

    private func calculateEarningsForValidator(
        _ validator: EraValidatorInfo,
        amount: Decimal,
        period: CalculationPeriod,
        resultType: RewardCalculationResultType
    ) -> Decimal {
        let commission = Decimal.fromSubstratePerbill(value: validator.prefs.commission) ?? 0.0
        let stake = Decimal.fromSubstrateAmount(
            validator.exposure.total,
            precision: assetPrecision
        ) ?? 0.0

        return calculateEarningsForAmount(
            amount,
            stake: stake,
            commission: commission,
            period: period,
            rewardAssetType: resultType
        )
    }

    private func calculateEarningsForAmount(
        _ amount: Decimal,
        stake: Decimal,
        commission: Decimal,
        period: CalculationPeriod,
        rewardAssetType: RewardCalculationResultType
    ) -> Decimal {
        let rate = rewardAssetType.calculateRate(givenRate: rewardAssetRate)
        let eraReturn = calculateReturnForStake(stake, commission: commission)
        let dailyReturn = eraReturn * erasPerDay

        return amount * rate * dailyReturn * Decimal(period.inDays)
    }
}
