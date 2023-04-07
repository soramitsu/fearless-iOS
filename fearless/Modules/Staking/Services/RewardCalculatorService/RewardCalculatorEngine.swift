import Foundation
import RobinHood
import BigInt
import IrohaCrypto

enum RewardCalculationResultType {
    case value
    case percent

    func calculateRate(givenRate: Decimal) -> Decimal {
        switch self {
        case .percent:
            return givenRate
        case .value:
            return 1.0
        }
    }
}

enum RewardReturnType {
    case max(_ validatorId: AccountId? = nil)
    case avg
}

enum CalculationPeriod {
    case day
    case month
    case year
    case custom(days: Int)

    var inDays: Int {
        switch self {
        case .day:
            return 1
        case .month:
            return 30
        case .year:
            return 365
        case let .custom(value):
            return value
        }
    }
}

protocol RewardCalculatorEngineProtocol {
    func calculateEarnings(
        amount: Decimal,
        validatorAccountId: AccountId,
        isCompound: Bool,
        period: CalculationPeriod
    ) throws -> Decimal

    func calculateMaxEarnings(
        amount: Decimal,
        isCompound: Bool,
        period: CalculationPeriod
    ) -> Decimal

    func calculateAvgEarnings(
        amount: Decimal,
        isCompound: Bool,
        period: CalculationPeriod
    ) -> Decimal

    func calculatorReturn(
        isCompound: Bool,
        period: CalculationPeriod,
        type: RewardReturnType
    ) -> Decimal

    func maxEarningsTitle(locale: Locale) -> String
    func avgEarningTitle(locale: Locale) -> String
}

extension RewardCalculatorEngineProtocol {
    func calculateValidatorReturn(
        validatorAccountId: AccountId,
        isCompound: Bool,
        period: CalculationPeriod
    ) throws -> Decimal {
        try calculateEarnings(
            amount: 1.0,
            validatorAccountId: validatorAccountId,
            isCompound: isCompound,
            period: period
        )
    }
}

enum RewardCalculatorEngineError: Error {
    case unexpectedValidator(accountId: Data)
}

final class ParachainRewardCalculatorEngine: RewardCalculatorEngineProtocol {
    private var totalIssuance: Decimal
    private var totalStaked: Decimal

    private let chainId: ChainModel.Id
    private let assetPrecision: Int16
    private let eraDurationInSeconds: TimeInterval
    private let commission: Decimal
    private let collators: [ParachainStakingCandidateInfo]

    private let decayRate: Decimal = 0.05
    private let idealStakePortion: Decimal = 0.75
    private let idealInflation: Decimal = 0.1
    private let minimalInflation: Decimal = 0.025

    init(
        chainId: ChainModel.Id,
        assetPrecision: Int16,
        totalIssuance: BigUInt,
        totalStaked: BigUInt,
        eraDurationInSeconds: TimeInterval,
        commission: Decimal,
        collators: [ParachainStakingCandidateInfo]
    ) {
        self.chainId = chainId
        self.assetPrecision = assetPrecision
        self.totalIssuance = Decimal.fromSubstrateAmount(
            totalIssuance,
            precision: assetPrecision
        ) ?? 0.0
        self.totalStaked = Decimal.fromSubstrateAmount(
            totalStaked,
            precision: assetPrecision
        ) ?? 0.0
        self.eraDurationInSeconds = eraDurationInSeconds
        self.commission = commission
        self.collators = collators
    }

    private lazy var annualInflation: Decimal = {
        0.025
    }()

    func avgEarningTitle(locale: Locale) -> String {
        R.string.localizable.parachainStakingRewardInfoAvg(preferredLanguages: locale.rLanguages)
    }

    func maxEarningsTitle(locale: Locale) -> String {
        R.string.localizable.parachainStakingRewardInfoMax(preferredLanguages: locale.rLanguages)
    }

    func calculateEarnings(
        amount _: Decimal,
        validatorAccountId _: Data,
        isCompound _: Bool,
        period: CalculationPeriod
    ) throws -> Decimal {
        dailyPercentReward() * Decimal(period.inDays)
    }

    func calculateMaxEarnings(amount _: Decimal, isCompound _: Bool, period: CalculationPeriod) -> Decimal {
        Decimal(collators.compactMap { $0.subqueryData?.apr }.max() ?? 0.0) / 365 * Decimal(period.inDays) / 100
    }

    func calculateAvgEarnings(amount _: Decimal, isCompound _: Bool, period: CalculationPeriod) -> Decimal {
        dailyPercentReward() * Decimal(period.inDays)
    }

    func calculatorReturn(isCompound: Bool, period: CalculationPeriod, type _: RewardReturnType) -> Decimal {
        calculateAvgEarnings(amount: 1.0, isCompound: isCompound, period: period)
    }

    private func dailyPercentReward() -> Decimal {
        ((totalIssuance * annualInflation) / totalStaked) / 365
    }

    private func calculateReturnForStake(_: Decimal, commission _: Decimal) -> Decimal {
        (totalIssuance * annualInflation) / totalStaked
    }

    private func calculateEarningsForCollator(
        _: ParachainStakingCandidateInfo,
        amount _: Decimal,
        isCompound _: Bool,
        period: CalculationPeriod
    ) -> Decimal {
        dailyPercentReward() * Decimal(period.inDays)
    }

    private func calculateEarningsForAmount(
        _ amount: Decimal,
        stake: Decimal,
        commission: Decimal,
        isCompound: Bool,
        period: CalculationPeriod
    ) -> Decimal {
        let annualReturn = calculateReturnForStake(stake, commission: commission)

        let dailyReturn = annualReturn / 365.0

        if isCompound {
            return calculateCompoundReward(
                initialAmount: amount,
                period: period,
                dailyInterestRate: dailyReturn
            )
        } else {
            return amount * dailyReturn * Decimal(period.inDays)
        }
    }

    // MARK: - Private

    // Calculation formula: R = P(1 + r/n)^nt - P, where
    // P – original amount
    // r - daily interest rate
    // n - number of eras in a day
    // t - number of days
    private func calculateCompoundReward(
        initialAmount: Decimal,
        period: CalculationPeriod,
        dailyInterestRate: Decimal
    ) -> Decimal {
        let numberOfDays = period.inDays
        let erasPerDay = eraDurationInSeconds.intervalsInDay

        guard erasPerDay > 0 else {
            return 0.0
        }

        let compoundedInterest = pow(1.0 + dailyInterestRate / Decimal(erasPerDay), erasPerDay * numberOfDays)
        let finalAmount = initialAmount * compoundedInterest

        return finalAmount - initialAmount
    }
}

// For all the cases we suggest that parachains are disabled
// Thus, i_ideal = 0.1 and x_ideal = 0.75
final class RewardCalculatorEngine: RewardCalculatorEngineProtocol {
    private var totalIssuance: Decimal
    private var validators: [EraValidatorInfo] = []
    private var rewardAssetRate: Decimal

    private let chainId: ChainModel.Id
    private let assetPrecision: Int16
    private let eraDurationInSeconds: TimeInterval

    private let decayRate: Decimal = 0.05
    private let idealStakePortion: Decimal = 0.75
    private let idealInflation: Decimal = 0.1
    private let minimalInflation: Decimal = 0.025

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

    private var stakedPortion: Decimal {
        if totalIssuance > 0.0 {
            return totalStake / totalIssuance
        } else {
            return 0.0
        }
    }

    private lazy var annualInflation: Decimal = {
        let idealInterest = idealInflation / idealStakePortion

        if stakedPortion <= idealStakePortion {
            return minimalInflation + stakedPortion *
                (idealInterest - minimalInflation / idealStakePortion)
        } else {
            let powerValue = (idealStakePortion - stakedPortion) / decayRate
            let doublePowerValue = Double(truncating: powerValue as NSNumber)
            let decayCoefficient = Decimal(pow(2, doublePowerValue))
            return minimalInflation + (idealInterest * idealStakePortion - minimalInflation)
                * decayCoefficient
        }
    }()

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
            calculateEarningsForValidator($0, amount: 1.0, isCompound: false, period: .year, resultType: .percent) <
                calculateEarningsForValidator($1, amount: 1.0, isCompound: false, period: .year, resultType: .percent)
        }
    }()

    init(
        chainId: ChainModel.Id,
        assetPrecision: Int16,
        totalIssuance: BigUInt,
        validators: [EraValidatorInfo],
        eraDurationInSeconds: TimeInterval,
        rewardAssetRate: Decimal = 1.0
    ) {
        self.chainId = chainId
        self.assetPrecision = assetPrecision
        self.totalIssuance = Decimal.fromSubstrateAmount(
            totalIssuance,
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
        isCompound: Bool,
        period: CalculationPeriod
    ) throws -> Decimal {
        guard let validator = validators.first(where: { $0.accountId == validatorAccountId }) else {
            throw RewardCalculatorEngineError.unexpectedValidator(accountId: validatorAccountId)
        }

        return calculateEarningsForValidator(
            validator,
            amount: amount,
            isCompound: isCompound,
            period: period,
            resultType: .value
        )
    }

    func calculateMaxEarnings(
        amount: Decimal,
        isCompound: Bool,
        period: CalculationPeriod
    ) -> Decimal {
        guard let validator = maxValidator else {
            return 0.0
        }

        return calculateEarningsForValidator(
            validator,
            amount: amount,
            isCompound: isCompound,
            period: period,
            resultType: .value
        )
    }

    func calculateAvgEarnings(
        amount: Decimal,
        isCompound: Bool,
        period: CalculationPeriod
    ) -> Decimal {
        calculateEarningsForAmount(
            amount,
            stake: averageStake,
            commission: medianCommission,
            isCompound: isCompound,
            period: period,
            rewardAssetType: .percent
        )
    }

    func calculatorReturn(isCompound: Bool, period: CalculationPeriod, type: RewardReturnType) -> Decimal {
        switch type {
        case .max:
            guard let validator = maxValidator else {
                return 0.0
            }

            return calculateEarningsForValidator(
                validator,
                amount: 1.0,
                isCompound: isCompound,
                period: period,
                resultType: .percent
            )
        case .avg:
            return calculateAvgEarnings(
                amount: 1.0,
                isCompound: isCompound,
                period: period
            )
        }
    }

    private func calculateReturnForStake(_ stake: Decimal, commission: Decimal) -> Decimal {
        (annualInflation * averageStake / (stakedPortion * stake)) * (1.0 - commission)
    }

    private func calculateEarningsForValidator(
        _ validator: EraValidatorInfo,
        amount: Decimal,
        isCompound: Bool,
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
            isCompound: isCompound,
            period: period,
            rewardAssetType: resultType
        )
    }

    private func calculateEarningsForAmount(
        _ amount: Decimal,
        stake: Decimal,
        commission: Decimal,
        isCompound: Bool,
        period: CalculationPeriod,
        rewardAssetType: RewardCalculationResultType
    ) -> Decimal {
        let rate = rewardAssetType.calculateRate(givenRate: rewardAssetRate)

        let annualReturn = calculateReturnForStake(stake, commission: commission)

        let dailyReturn = annualReturn / 365.0

        if isCompound {
            return calculateCompoundReward(
                initialAmount: amount * rate,
                period: period,
                dailyInterestRate: dailyReturn
            )
        } else {
            return amount * rate * dailyReturn * Decimal(period.inDays)
        }
    }

    // MARK: - Private

    // Calculation formula: R = P(1 + r/n)^nt - P, where
    // P – original amount
    // r - daily interest rate
    // n - number of eras in a day
    // t - number of days
    private func calculateCompoundReward(
        initialAmount: Decimal,
        period: CalculationPeriod,
        dailyInterestRate: Decimal
    ) -> Decimal {
        let numberOfDays = period.inDays
        let erasPerDay = eraDurationInSeconds.intervalsInDay

        guard erasPerDay > 0 else {
            return 0.0
        }

        let compoundedInterest = pow(1.0 + dailyInterestRate / Decimal(erasPerDay), erasPerDay * numberOfDays)
        let finalAmount = initialAmount * compoundedInterest

        return finalAmount - initialAmount
    }
}
