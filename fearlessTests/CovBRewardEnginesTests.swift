import XCTest
import BigInt
import SSFModels
@testable import fearless

func covBReAssertClose(
    _ value: Decimal,
    _ expected: Double,
    accuracy: Double = 1e-9,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    let actual = NSDecimalNumber(decimal: value).doubleValue
    XCTAssertEqual(actual, expected, accuracy: max(accuracy, abs(expected) * 1e-9), file: file, line: line)
}

enum CovBReFixtures {
    typealias Fx = CovBSkFixtures

    /// A: 30 staked at 10 %, B: 10 staked at 0 %, C: 20 staked at 100 % commission.
    static func validators() throws -> [EraValidatorInfo] {
        [
            try Fx.validator(Fx.validatorA, total: 30, own: 30, commission: 100_000_000),
            try Fx.validator(Fx.validatorB, total: 10, own: 10, commission: 0),
            try Fx.validator(Fx.validatorC, total: 20, own: 20, commission: 1_000_000_000)
        ]
    }

    static func compound(daily: Double, erasPerDay: Double, days: Double) -> Double {
        pow(1 + daily / erasPerDay, erasPerDay * days) - 1
    }
}

final class CovBReRelaychainEngineTests: XCTestCase {
    typealias Fx = CovBSkFixtures

    private func engine(totalIssuance: BigUInt = 100, validators: [EraValidatorInfo]? = nil, era: TimeInterval = 21600) throws -> RewardCalculatorEngine {
        RewardCalculatorEngine(
            chainId: "covb-relay",
            assetPrecision: 0,
            totalIssuance: totalIssuance,
            validators: try validators ?? CovBReFixtures.validators(),
            eraDurationInSeconds: era,
            rewardAssetRate: 3
        )
    }

    // Staked portion 0.6 is below the ideal 0.75, so inflation is 0.025 + 0.6 * (0.1 / 0.75 - 0.025 / 0.75) = 0.085.
    private let inflation = 0.085
    private func annualReturn(stake: Double, commission: Double, inflation: Double = 0.085, portion: Double = 0.6) -> Double {
        inflation * 20 / (portion * stake) * (1 - commission)
    }

    func testValidatorEarningsFollowTheInflationCurve() throws {
        let engine = try engine()
        covBReAssertClose(try engine.calculateEarnings(amount: 100, validatorAccountId: Fx.validatorA, isCompound: false, period: .year), 8.5)
        covBReAssertClose(
            try engine.calculateEarnings(amount: 1, validatorAccountId: Fx.validatorB, isCompound: false, period: .month),
            annualReturn(stake: 10, commission: 0) / 365 * 30
        )
        covBReAssertClose(try engine.calculateEarnings(amount: 5, validatorAccountId: Fx.validatorC, isCompound: false, period: .year), 0)
        XCTAssertEqual(engine.rewardAssetRate, 3, "Percent results ignore the reward asset rate")
    }

    func testCompoundEarningsReinvestEveryEra() throws {
        let engine = try engine()
        let daily = annualReturn(stake: 10, commission: 0) / 365
        covBReAssertClose(
            try engine.calculateEarnings(amount: 2, validatorAccountId: Fx.validatorB, isCompound: true, period: .year),
            2 * CovBReFixtures.compound(daily: daily, erasPerDay: 4, days: 365),
            accuracy: 1e-6
        )
    }

    func testMaximumUsesTheMostProfitableValidatorAndAverageTheMedianCommission() throws {
        let engine = try engine()
        let best = annualReturn(stake: 10, commission: 0)
        covBReAssertClose(engine.calculateMaxEarnings(amount: 2, isCompound: false, period: .year), 2 * best)
        // Profitable commissions are 0 and 0.1 (100 % is excluded), so the median is 0.05.
        let average = annualReturn(stake: 20, commission: 0.05)
        covBReAssertClose(engine.calculateAvgEarnings(amount: 1, isCompound: false, period: .year), average)
        covBReAssertClose(engine.calculatorReturn(isCompound: false, period: .custom(days: 10), type: .max()), best / 365 * 10)
        covBReAssertClose(
            engine.calculatorReturn(isCompound: true, period: .year, type: .max()),
            CovBReFixtures.compound(daily: best / 365, erasPerDay: 4, days: 365),
            accuracy: 1e-6
        )
        covBReAssertClose(engine.calculatorReturn(isCompound: false, period: .day, type: .avg), average / 365)
    }

    func testStakeAboveTheIdealPortionDecaysInflation() throws {
        let engine = try engine(totalIssuance: 70)
        let portion = 60.0 / 70.0
        let decayed = 0.025 + 0.075 * pow(2, (0.75 - portion) / 0.05)
        covBReAssertClose(
            try engine.calculateEarnings(amount: 1, validatorAccountId: Fx.validatorA, isCompound: false, period: .year),
            annualReturn(stake: 30, commission: 0.1, inflation: decayed, portion: portion),
            accuracy: 1e-6
        )
    }

    func testEmptyValidatorSetAndZeroEraDurationEarnNothing() throws {
        let empty = try engine(validators: [])
        XCTAssertEqual(empty.calculateMaxEarnings(amount: 1, isCompound: false, period: .year), 0)
        XCTAssertEqual(empty.calculatorReturn(isCompound: false, period: .year, type: .max()), 0)
        let noEras = try engine(era: 0)
        XCTAssertEqual(try noEras.calculateEarnings(amount: 1, validatorAccountId: Fx.validatorB, isCompound: true, period: .year), 0)
    }

    func testUnknownValidatorThrowsAndTitlesAreLocalized() throws {
        let engine = try engine()
        XCTAssertThrowsError(try engine.calculateEarnings(amount: 1, validatorAccountId: Fx.validatorD, isCompound: false, period: .day)) {
            guard case let RewardCalculatorEngineError.unexpectedValidator(accountId) = $0 else { return XCTFail("unexpected \($0)") }
            XCTAssertEqual(accountId, Fx.validatorD)
        }
        let locale = Locale(identifier: "en")
        XCTAssertEqual(engine.avgEarningTitle(locale: locale), R.string.localizable.stakingRewardInfoAvg(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(engine.maxEarningsTitle(locale: locale), R.string.localizable.stakingRewardInfoMax(preferredLanguages: locale.rLanguages))
    }
}

final class CovBRePortionEngineTests: XCTestCase {
    typealias Fx = CovBSkFixtures

    // 120 per era shared by three validators gives each 40; with 6 hour eras there are 4 eras a day.
    private func engine(validators: [EraValidatorInfo]? = nil) throws -> PortionRewardCalculatorEngine {
        PortionRewardCalculatorEngine(
            chainId: "covb-para",
            assetPrecision: 0,
            averageTotalRewardsPerEra: 120,
            validators: try validators ?? CovBReFixtures.validators(),
            eraDurationInSeconds: 21600
        )
    }

    func testValidatorEarningsSplitTheEraRewardsByStake() throws {
        let engine = try engine()
        covBReAssertClose(try engine.calculateEarnings(amount: 1, validatorAccountId: Fx.validatorA, isCompound: false, period: .day), 4.8)
        covBReAssertClose(try engine.calculateEarnings(amount: 1, validatorAccountId: Fx.validatorA, isCompound: false, period: .year), 1752)
        covBReAssertClose(try engine.calculateEarnings(amount: 1, validatorAccountId: Fx.validatorB, isCompound: true, period: .day), 624)
        covBReAssertClose(try engine.calculateEarnings(amount: 1, validatorAccountId: Fx.validatorA, isCompound: true, period: .day), 22.4256)
        XCTAssertEqual(engine.rewardAssetRate, 1)
    }

    func testMaximumAverageAndReturns() throws {
        let engine = try engine()
        covBReAssertClose(engine.calculateMaxEarnings(amount: 1, isCompound: false, period: .day), 16)
        covBReAssertClose(engine.calculateAvgEarnings(amount: 1, isCompound: false, period: .day), 7.6)
        covBReAssertClose(engine.calculatorReturn(isCompound: false, period: .day, type: .max()), 16)
        covBReAssertClose(engine.calculatorReturn(isCompound: true, period: .day, type: .max()), 624)
        // The average return uses the mean commission of all validators, (0.1 + 0 + 1) / 3.
        let mean = 40.0 / 20.0 * (1 - 1.1 / 3) * 4
        covBReAssertClose(engine.calculatorReturn(isCompound: false, period: .day, type: .avg), mean, accuracy: 1e-9)
        covBReAssertClose(engine.calculatorReturn(isCompound: true, period: .day, type: .avg), pow(1 + mean / 4, 4) - 1, accuracy: 1e-6)
    }

    func testEmptyValidatorSetHasNoMaximumAndUnknownValidatorThrows() throws {
        let empty = try engine(validators: [])
        XCTAssertEqual(empty.calculateMaxEarnings(amount: 1, isCompound: false, period: .day), 0)
        XCTAssertEqual(empty.calculatorReturn(isCompound: false, period: .day, type: .max()), 0)
        XCTAssertThrowsError(try engine().calculateEarnings(amount: 1, validatorAccountId: Fx.validatorD, isCompound: false, period: .day))
        let locale = Locale(identifier: "en")
        XCTAssertEqual(try engine().avgEarningTitle(locale: locale), R.string.localizable.stakingRewardInfoAvg(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(try engine().maxEarningsTitle(locale: locale), R.string.localizable.stakingRewardInfoMax(preferredLanguages: locale.rLanguages))
    }
}

final class CovBReSoraEngineTests: XCTestCase {
    typealias Fx = CovBSkFixtures

    private func points(total: UInt32, _ individual: [(Data, UInt32)]) throws -> EraRewardPoints {
        let json: [String: Any] = [
            "total": String(total),
            "individual": individual.map { [$0.0.base64EncodedString(), String($0.1)] }
        ]
        return try JSONDecoder().decode(EraRewardPoints.self, from: JSONSerialization.data(withJSONObject: json))
    }

    /// Eras 1 and 2 count; the latest era 3 is still running and is left out.
    private func engine() throws -> SoraRewardCalculatorEngine {
        let chain = Fx.chain(id: "covb-sora", precision: 0)
        let asset = try XCTUnwrap(chain.assets.first)
        return SoraRewardCalculatorEngine(
            totalStakeByEra: [1: 1000],
            rewardPointsByEra: [
                1: try points(total: 100, [(Fx.validatorA, 60), (Fx.validatorB, 40)]),
                2: try points(total: 200, [(Fx.validatorA, 100), (Fx.validatorB, 100)]),
                3: try points(total: 999, [(Fx.validatorA, 999)])
            ],
            validatorRewardsByEra: [1: 1000, 2: 2000, 3: 99999],
            validators: [
                try Fx.validator(Fx.validatorA, total: 400, own: 400, commission: 100_000_000),
                try Fx.validator(Fx.validatorB, total: 700, own: 700, commission: 0),
                try Fx.validator(Fx.validatorC, total: 0, own: 0, commission: 0)
            ],
            chainAsset: ChainAsset(chain: chain, asset: asset),
            eraDurationInSeconds: 21600,
            rewardAssetRate: 2
        )
    }

    func testValidatorEarningsUseTheirShareOfPastEraPayouts() throws {
        let engine = try engine()
        // A: 80 of 150 average points of a 1500 payout is 800 VAL over 400 XOR at rate 2, less 10 % commission.
        covBReAssertClose(try engine.calculateEarnings(amount: 1, validatorAccountId: Fx.validatorA, isCompound: false, period: .day), 3.6)
        covBReAssertClose(try engine.calculateEarnings(amount: 1, validatorAccountId: Fx.validatorA, isCompound: true, period: .year), 1314)
        covBReAssertClose(try engine.calculateEarnings(amount: 1, validatorAccountId: Fx.validatorB, isCompound: false, period: .day), 2)
        XCTAssertThrowsError(try engine.calculateEarnings(amount: 1, validatorAccountId: Fx.validatorD, isCompound: false, period: .day))
    }

    func testMaximumAndAverageCoverElectedValidatorsOnly() throws {
        let engine = try engine()
        covBReAssertClose(engine.calculateMaxEarnings(amount: 1, isCompound: false, period: .day), 3.6)
        covBReAssertClose(engine.calculateAvgEarnings(amount: 1, isCompound: false, period: .day), 2.8)
        covBReAssertClose(engine.calculatorReturn(isCompound: false, period: .day, type: .max(Fx.validatorB)), 2)
        covBReAssertClose(engine.calculatorReturn(isCompound: false, period: .day, type: .max()), 3.6)
        covBReAssertClose(engine.calculatorReturn(isCompound: false, period: .day, type: .avg), 2.8)
        XCTAssertEqual(engine.calculatorReturn(isCompound: false, period: .day, type: .max(Fx.validatorD)), 0)
        XCTAssertEqual(engine.rewardAssetRate, 2)
        let locale = Locale(identifier: "en")
        XCTAssertEqual(engine.avgEarningTitle(locale: locale), R.string.localizable.stakingRewardInfoAvg(preferredLanguages: locale.rLanguages))
        XCTAssertEqual(engine.maxEarningsTitle(locale: locale), R.string.localizable.stakingRewardInfoMax(preferredLanguages: locale.rLanguages))
    }
}
