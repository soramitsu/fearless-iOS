import Foundation
import RobinHood
import BigInt
import IrohaCrypto

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
    func calculateEarnings(amount: Decimal,
                           validatorAccountId: Data?,
                           isCompound: Bool,
                           period: CalculationPeriod) throws -> Decimal
}

extension RewardCalculatorEngineProtocol {
    func calculateValidatorReturn(validatorAccountId: Data,
                                  isCompound: Bool,
                                  period: CalculationPeriod) throws -> Decimal {

        try calculateEarnings(amount: 1.0,
                              validatorAccountId: validatorAccountId,
                              isCompound: isCompound,
                              period: period)
    }

    func calculateNetworkReturn(isCompound: Bool, period: CalculationPeriod) throws -> Decimal {
        try calculateEarnings(amount: 1.0,
                              validatorAccountId: nil,
                              isCompound: isCompound,
                              period: period)
    }

    func calculateNetworkEarnings(amount: Decimal,
                                  isCompound: Bool,
                                  period: CalculationPeriod) throws -> Decimal {
        try calculateEarnings(amount: amount,
                              validatorAccountId: nil,
                              isCompound: isCompound,
                              period: period)
    }
}

enum RewardCalculatorEngineError: Error {
    case unexpectedValidator(accountId: Data)
}

// For all the cases we suggest that parachains are disabled
// Thus, i_ideal = 0.1 and x_ideal = 0.75
final class RewardCalculatorEngine: RewardCalculatorEngineProtocol {
    private var totalIssuance: Decimal
    private var validators: [EraValidatorInfo] = []

    private let chain: Chain

    private let decayRate: Decimal = 0.05
    private let idealStakePortion: Decimal = 0.75
    private let idealInflation: Decimal = 0.1
    private let minimalInflation: Decimal = 0.025

    private lazy var totalStake: Decimal = {
        Decimal.fromSubstrateAmount(validators.map({$0.exposure.total}).reduce(0, +),
                                    precision: chain.addressType.precision) ?? 0.0
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
        let sorted = validators.map({ $0.prefs.commission }).sorted()

        guard !sorted.isEmpty else {
            return 0.0
        }

        let commission: BigUInt

        if sorted.count % 2 == 0 {
            commission = (sorted[(sorted.count / 2)] + sorted[(sorted.count / 2) - 1]) / 2
        } else {
            commission = sorted[(sorted.count - 1) / 2]
        }

        return Decimal.fromSubstratePerbill(value: commission) ?? 0.0
    }()

    init(totalIssuance: BigUInt,
         validators: [EraValidatorInfo],
         chain: Chain) {
        self.totalIssuance = Decimal.fromSubstrateAmount(totalIssuance,
                                                         precision: chain.addressType.precision) ?? 0.0
        self.validators = validators
        self.chain = chain
    }

    func calculateEarnings(amount: Decimal,
                           validatorAccountId: Data?,
                           isCompound: Bool,
                           period: CalculationPeriod) throws -> Decimal {
        let annualReturn: Decimal

        if let accountId = validatorAccountId {
            guard let validator = validators.first(where: { $0.accountId == accountId }) else {
                throw RewardCalculatorEngineError.unexpectedValidator(accountId: accountId)
            }

            let commission = Decimal.fromSubstratePerbill(value: validator.prefs.commission) ?? 0.0
            let stake = Decimal.fromSubstrateAmount(validator.exposure.total,
                                                    precision: chain.addressType.precision) ?? 0.0

            annualReturn = calculateForValidator(stake: stake, commission: commission)
        } else {
            annualReturn = calculateForValidator(stake: averageStake, commission: medianCommission)
        }

        let dailyReturn = annualReturn / 365.0

        if isCompound {
            return calculateCompoundReward(initialAmount: amount,
                                           period: period,
                                           dailyInterestRate: dailyReturn)
        } else {
            return amount * dailyReturn * Decimal(period.inDays)
        }
    }

    private func calculateForValidator(stake: Decimal, commission: Decimal) -> Decimal {
        (annualInflation * averageStake / (stakedPortion * stake)) * (1.0 - commission)
    }

    // MARK: - Private
    // Calculation formula: R = P(1 + r/n)^nt - P, where
    // P – original amount
    // r - daily interest rate
    // n - number of eras in a day
    // t - number of days
    private func calculateCompoundReward(initialAmount: Decimal,
                                         period: CalculationPeriod,
                                         dailyInterestRate: Decimal) -> Decimal {
        let numberOfDays = period.inDays
        let erasPerDay = chain.erasPerDay

        guard erasPerDay > 0 else {
            return 0.0
        }

        let compoundedInterest = pow(1.0 + dailyInterestRate/Decimal(erasPerDay), erasPerDay * numberOfDays)
        let finalAmount = initialAmount * compoundedInterest

        return finalAmount - initialAmount
    }
}
