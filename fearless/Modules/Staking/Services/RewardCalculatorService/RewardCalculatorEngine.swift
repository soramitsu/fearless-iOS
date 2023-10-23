import Foundation
import RobinHood
import BigInt
import IrohaCrypto

enum RewardCalculationResultType {
    case value
    case percent

    /*
     Rate for reward calculation. Some networks have different reward tokens than user stakes. (e.g. SORA - user stakes XOR, but receives VAL)
     For these cases we need to calculate APR, APY with a rate equal to RewardTokenPrice / StakedTokenPrice.
     For the common cases, the givenRate is equal to 1.0
     */
    func calculateRate(givenRate: Decimal) -> Decimal {
        switch self {
        case .percent:
            return 1.0
        case .value:
            return givenRate
        }
    }
}

enum RewardCalculatorConstants {
    static let percentCalculationAmount: Decimal = 1.0
    static let defaultRewardAssetRate: Decimal = 1.0
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
    var rewardAssetRate: Decimal { get }

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
