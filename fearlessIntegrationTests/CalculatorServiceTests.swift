import XCTest
import BigInt
@testable import fearless

final class CalculatorServiceTests: XCTestCase {
    func testRelaychainCalculator_whenSingleValidator_thenMaxAvgAndValidatorReturnsMatch() throws {
        let validator = makeValidator(
            accountId: Data(repeating: 1, count: 32),
            stake: BigUInt(1_000_000_000_000_000),
            commission: BigUInt(100_000_000)
        )
        let engine = makeRelaychainEngine(validators: [validator])

        let validatorReturn = try engine.calculateEarnings(
            amount: 100,
            validatorAccountId: validator.accountId,
            isCompound: false,
            period: .year
        )
        let maxReturn = engine.calculateMaxEarnings(amount: 100, isCompound: false, period: .year)
        let avgReturn = engine.calculateAvgEarnings(amount: 100, isCompound: false, period: .year)
        let percentageReturn = engine.calculatorReturn(isCompound: false, period: .year, type: .max())

        XCTAssertGreaterThan(validatorReturn, 0)
        XCTAssertEqual(validatorReturn, maxReturn)
        XCTAssertEqual(validatorReturn, avgReturn)
        XCTAssertEqual(validatorReturn, percentageReturn * 100)
    }

    func testRelaychainCalculator_whenCompounding_thenReturnsMoreThanSimpleInterest() {
        let validator = makeValidator(
            accountId: Data(repeating: 2, count: 32),
            stake: BigUInt(1_000_000_000_000_000),
            commission: BigUInt(0)
        )
        let engine = makeRelaychainEngine(validators: [validator])

        let simpleReturn = engine.calculateMaxEarnings(amount: 100, isCompound: false, period: .year)
        let compoundReturn = engine.calculateMaxEarnings(amount: 100, isCompound: true, period: .year)

        XCTAssertGreaterThan(compoundReturn, simpleReturn)
    }

    func testRelaychainCalculator_whenValidatorIsUnknown_thenThrowsUnexpectedValidator() {
        let validator = makeValidator(
            accountId: Data(repeating: 3, count: 32),
            stake: BigUInt(1_000_000_000_000_000),
            commission: BigUInt(0)
        )
        let engine = makeRelaychainEngine(validators: [validator])

        XCTAssertThrowsError(
            try engine.calculateEarnings(
                amount: 1,
                validatorAccountId: Data(repeating: 9, count: 32),
                isCompound: false,
                period: .day
            )
        ) { error in
            guard case RewardCalculatorEngineError.unexpectedValidator = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    func testRelaychainCalculator_whenEraDurationIsZero_thenCompoundReturnIsZero() {
        let validator = makeValidator(
            accountId: Data(repeating: 4, count: 32),
            stake: BigUInt(1_000_000_000_000_000),
            commission: BigUInt(0)
        )
        let engine = makeRelaychainEngine(
            validators: [validator],
            eraDurationInSeconds: 0
        )

        let compoundReturn = engine.calculateMaxEarnings(amount: 100, isCompound: true, period: .year)

        XCTAssertEqual(compoundReturn, 0)
    }

    func testParachainCalculator_whenCollatorsHaveApr_thenMaxReturnUsesHighestApr() {
        let engine = ParachainRewardCalculatorEngine(
            chainId: "parachain",
            assetPrecision: 12,
            totalIssuance: BigUInt(2_000_000_000_000_000),
            totalStaked: BigUInt(1_000_000_000_000_000),
            eraDurationInSeconds: 7_200,
            commission: 0,
            collators: [
                makeCollator(address: "collator-a", apr: 12.0),
                makeCollator(address: "collator-b", apr: 18.0)
            ]
        )

        let yearlyMax = engine.calculateMaxEarnings(amount: 1, isCompound: false, period: .year)
        let dailyMax = engine.calculateMaxEarnings(amount: 1, isCompound: false, period: .day)

        XCTAssertEqual(NSDecimalNumber(decimal: yearlyMax).doubleValue, 0.18, accuracy: 0.000_000_001)
        XCTAssertEqual(NSDecimalNumber(decimal: dailyMax).doubleValue, 0.18 / 365.0, accuracy: 0.000_000_001)
    }

    private func makeRelaychainEngine(
        validators: [EraValidatorInfo],
        eraDurationInSeconds: TimeInterval = 21_600
    ) -> RewardCalculatorEngine {
        let totalIssuance = validators.reduce(BigUInt(0)) { $0 + $1.exposure.total }

        return RewardCalculatorEngine(
            chainId: "relay",
            assetPrecision: 12,
            totalIssuance: totalIssuance,
            validators: validators,
            eraDurationInSeconds: eraDurationInSeconds
        )
    }

    private func makeValidator(
        accountId: Data,
        stake: BigUInt,
        commission: BigUInt
    ) -> EraValidatorInfo {
        EraValidatorInfo(
            accountId: accountId,
            exposure: ValidatorExposure(
                total: stake,
                own: stake,
                others: []
            ),
            prefs: ValidatorPrefs(
                commission: commission,
                blocked: false
            )
        )
    }

    private func makeCollator(address: String, apr: Double) -> ParachainStakingCandidateInfo {
        ParachainStakingCandidateInfo(
            address: address,
            owner: Data(address.utf8),
            amount: AmountDecimal(value: 1_000),
            metadata: nil,
            identity: nil,
            subqueryData: SubqueryCollatorAprInfo(
                collatorId: address,
                apr: apr
            )
        )
    }
}
