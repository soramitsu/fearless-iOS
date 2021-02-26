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

extension RewardCalculatorEngineProtocol {
    func calculateForNominator(amount: Decimal,
                               accountId: Data?,
                               isCompound: Bool = false,
                               period: CalculationPeriod = .year) throws -> Decimal {
        return 0.0
    }

    func calculateForValidator(accountId: Data) -> Decimal {
        return 0.0
    }
}

// For all the cases we suggest that parachains are disabled
// Thus, i_ideal = 0.1 and x_ideal = 0.75
class RewardCalculatorEngine: RewardCalculatorEngineProtocol {
    var totalIssuance: Decimal
    var validators: [EraValidatorInfo] = []
    private let decayRate: Decimal = 0.05
    private let idealStakePortion: Decimal = 0.75
    private let idealInflation: Decimal = 0.1
    private let minimalInflation: Decimal = 0.025

    init(totalIssuance: Balance,
         validators: [EraValidatorInfo]) {
        self.totalIssuance = Decimal.fromSubstrateAmount(totalIssuance.value) ?? 0.0
        self.validators = validators
    }

    func calculateForNominator(amount: Decimal,
                               accountId: Data?,
                               address: String,
                               isCompound: Bool,
                               period: CalculationPeriod) throws -> Decimal {

        let totalStake = Decimal.fromSubstrateAmount(validators.map({$0.exposure.total}).reduce(0, +)) ?? 0.0

        let annualInflation = calculateAnnualInflation(totalStake: totalStake)

        let averageStake = calculateAverageStake(totalStake: totalStake)

        let stakePart = annualInflation * averageStake

        let commission = Decimal.fromSubstrateAmount(findMedianCommission(commissions: validators.map { $0.prefs.commission })) ?? 0.0

        let annualInterestRate = stakePart * (1.0 - commission)

        let dailyInterestRate = annualInterestRate / 365.0

        guard isCompound else {
            return amount * dailyInterestRate * Decimal(daysInPeriod(period: period))
        }

        let erasPerDay = try getErasPerDay(address: address)

        return amount * pow(dailyInterestRate / Decimal(erasPerDay),
                            erasPerDay * daysInPeriod(period: period))
    }

    func calculateForValidator(accountId: Data) -> Decimal {
        let totalStake = Decimal.fromSubstrateAmount(validators.map({$0.exposure.own}).reduce(0, +)) ?? 0.0

        let annualInflation = calculateAnnualInflation(totalStake: totalStake)

        let averageStake = calculateAverageStake(totalStake: totalStake)

        let stakedPortion = calculateStakedPortion(totalStake: totalStake)

        guard let validator = validators.first(where: { $0.accountId == accountId }) else { return 0.0 }

        let exposure = Decimal.fromSubstrateAmount(validator.exposure.total) ?? 0.0

        return annualInflation * averageStake / (stakedPortion * exposure)
    }

    // MARK: - Private
    private func getErasPerDay(address: String) throws -> Int {
        let addressFactory = SS58AddressFactory()
        let addressType = try addressFactory.extractAddressType(from: address)

        switch addressType {
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

        guard stakedPortion <= idealStakePortion else {
            print("Applying complex formula")
            let powerValue = (idealStakePortion - stakedPortion) / decayRate
            let doublePowerValue = Double(truncating: powerValue as NSNumber)
            let decayCoefficient = Decimal(pow(2, doublePowerValue))
            return minimalInflation + (idealInflation * idealStakePortion - minimalInflation)
                * decayCoefficient

        }
        print("Applying simple formula")
        return minimalInflation + stakedPortion *
            (idealInflation - minimalInflation / idealStakePortion) // 0.025 + 0.67 * (0.1 - 0.025 / 0.75)
    }

    private func findMedianCommission(commissions: [BigUInt]) -> BigUInt {
        let sorted = commissions.sorted()
        guard sorted.count % 2 == 0 else {
            return sorted[(sorted.count - 1) / 2]
        }

        return (sorted[(sorted.count / 2)] + sorted[(sorted.count / 2) - 1]) / 2
    }
}
