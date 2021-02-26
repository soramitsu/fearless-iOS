import Foundation
import RobinHood
import BigInt
import IrohaCrypto

extension Chain {
    var erasPerDay: Int {
        switch self {
        case .polkadot:
            return 1
        case .kusama, .westend:
            return 4
        }
    }
}

enum CalculationPeriod {
    case day
    case month
    case year
    case custom(days: Int)
}

protocol RewardCalculatorEngineProtocol {
    func calculateForNominator(amount: Decimal,
                               accountId: Data?,
                               isCompound: Bool,
                               period: CalculationPeriod) throws -> Decimal

    func calculateForValidator(accountId: Data) -> Decimal
}

// For all the cases we suggest that parachains are disabled
// Thus, i_ideal = 0.1 and x_ideal = 0.75
class RewardCalculatorEngine: RewardCalculatorEngineProtocol {
    private var totalIssuance: Decimal
    private var validators: [EraValidatorInfo] = []

    private let chain: Chain

    private let decayRate: Decimal = 0.05
    private let idealStakePortion: Decimal = 0.75
    private let idealInflation: Decimal = 0.1
    private let minimalInflation: Decimal = 0.025

    init(totalIssuance: BigUInt,
         validators: [EraValidatorInfo],
         chain: Chain) {
        self.totalIssuance = Decimal.fromSubstrateAmount(totalIssuance,
                                                         precision: chain.addressType.precision) ?? 0.0
        self.validators = validators
        self.chain = chain
    }

    func calculateForNominator(amount: Decimal,
                               accountId: Data?,
                               isCompound: Bool,
                               period: CalculationPeriod) throws -> Decimal {

        let totalStake = Decimal.fromSubstrateAmount(validators.map({$0.exposure.total}).reduce(0, +),
                                                     precision: chain.addressType.precision) ?? 0.0

        let annualInflation = calculateAnnualInflation(totalStake: totalStake)

        let averageStake = calculateAverageStake(totalStake: totalStake)

        let stakePart = annualInflation * averageStake

        let median = findMedianCommission(commissions: validators.map { $0.prefs.commission })
        let commission = Decimal.fromSubstratePerbill(median) ?? 0.0

        let annualInterestRate = stakePart * (1.0 - commission)

        let dailyInterestRate = annualInterestRate / 365.0

        guard isCompound else {
            return amount * dailyInterestRate * Decimal(daysInPeriod(period: period))
        }

        let erasPerDay = try getErasPerDay()

        return amount * pow(dailyInterestRate / Decimal(erasPerDay),
                            erasPerDay * daysInPeriod(period: period))
    }

    func calculateForValidator(accountId: Data) -> Decimal {
        let totalStake = Decimal.fromSubstrateAmount(validators.map({$0.exposure.total}).reduce(0, +),
                                                     precision: chain.addressType.precision) ?? 0.0

        let annualInflation = calculateAnnualInflation(totalStake: totalStake)

        let averageStake = calculateAverageStake(totalStake: totalStake)

        let stakedPortion = calculateStakedPortion(totalStake: totalStake)

        guard let validator = validators.first(where: { $0.accountId == accountId }) else { return 0.0 }

        let exposure = Decimal.fromSubstrateAmount(validator.exposure.total,
                                                   precision: chain.addressType.precision) ?? 0.0

        let commission = Decimal.fromSubstratePerbill(validator.prefs.commission) ?? 0.0

        return (annualInflation * averageStake / (stakedPortion * exposure)) * (1.0 - commission)
    }

    // MARK: - Private
    private func getErasPerDay() throws -> Int {
        switch chain.addressType {
        case .polkadotMain:
            return 1
        case .genericSubstrate:
            return 4
        default:
            return 4
        }
    }

    private func daysInPeriod(period: CalculationPeriod) -> Int {
        switch period {
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

    private func calculateAverageStake(totalStake: Decimal) -> Decimal {
        return totalStake / Decimal(validators.count)
    }

    private func calculateStakedPortion(totalStake: Decimal) -> Decimal {
        return totalStake / totalIssuance
    }

    private func calculateAnnualInflation(totalStake: Decimal) -> Decimal {
        let stakedPortion = calculateStakedPortion(totalStake: totalStake)

        let idealInterest = idealInflation / idealStakePortion

        guard stakedPortion <= idealStakePortion else {
            let powerValue = (idealStakePortion - stakedPortion) / decayRate
            let doublePowerValue = Double(truncating: powerValue as NSNumber)
            let decayCoefficient = Decimal(pow(2, doublePowerValue))
            return minimalInflation + (idealInterest * idealStakePortion - minimalInflation)
                * decayCoefficient

        }

        return minimalInflation + stakedPortion *
            (idealInterest - minimalInflation / idealStakePortion) // 0.025 + 0.67 * (0.1 - 0.025 / 0.75)
    }

    private func findMedianCommission(commissions: [BigUInt]) -> BigUInt {
        let sorted = commissions.sorted()
        guard sorted.count % 2 == 0 else {
            return sorted[(sorted.count - 1) / 2]
        }

        return (sorted[(sorted.count / 2)] + sorted[(sorted.count / 2) - 1]) / 2
    }
}
