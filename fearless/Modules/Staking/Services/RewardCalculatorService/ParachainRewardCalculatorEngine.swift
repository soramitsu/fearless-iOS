import Foundation
import RobinHood
import Web3
import IrohaCrypto
import SSFModels
import SSFModels

final class ParachainRewardCalculatorEngine: RewardCalculatorEngineProtocol {
    private var totalIssuance: Decimal
    private var totalStaked: Decimal
    private let chainId: ChainModel.Id
    private let assetPrecision: Int16
    private let eraDurationInSeconds: TimeInterval
    private let commission: Decimal
    private let collators: [ParachainStakingCandidateInfo]

    private lazy var annualInflation: Decimal = {
        0.025
    }()

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
        calculateAvgEarnings(amount: RewardCalculatorConstants.percentCalculationAmount, isCompound: isCompound, period: period)
    }

    // MARK: - Private

    private func dailyPercentReward() -> Decimal {
        ((totalIssuance * annualInflation) / totalStaked) / 365
    }

    private func calculateReturnForStake(_: Decimal, commission _: Decimal) -> Decimal {
        (totalIssuance * annualInflation) / totalStaked
    }

    private func calculateEarningsForCollator(
        _: ParachainStakingCandidateInfo,
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
