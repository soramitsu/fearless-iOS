import XCTest
import SSFModels
import BigInt
@testable import fearless

final class CovCPJPoolRewardCalculatorTests: XCTestCase {
    private let oneToken = BigUInt(10_000_000_000)

    private func rewards(claimed: BigUInt, payouts: BigUInt) -> StakingPoolRewards {
        StakingPoolRewards(lastRecordedRewardCounter: 0, lastRecordedTotalPayouts: payouts, totalRewardsClaimed: claimed)
    }

    private func calculate(
        poolPoints: BigUInt,
        poolFree: BigUInt,
        memberPoints: String,
        claimed: BigUInt,
        payouts: BigUInt,
        price: PriceData?
    ) throws -> PoolRewardCalculatorResult {
        let chainAsset = CovCPJFixtures.chainAsset(precision: 10)
        return StakinkPoolRewardCalculator().calculate(
            wallet: CovCPJFixtures.wallet(),
            chainAsset: chainAsset,
            poolInfo: CovCPJFixtures.pool(id: "1", name: "Pool", points: poolPoints, members: 3),
            poolAccountInfo: CovCPJFixtures.accountInfo(free: poolFree),
            poolRewards: rewards(claimed: claimed, payouts: payouts),
            stakeInfo: try CovCPJFixtures.poolMember(poolId: 1, points: memberPoints),
            existentialDeposit: oneToken,
            priceData: price,
            locale: CovCPJFixtures.locale
        )
    }

    func testPendingRewardIsMemberShareOfUnrecordedPayout() throws {
        // Pool holds 1000 tokens, the member 100; 10 tokens above the deposit are unrecorded payouts.
        let result = try calculate(
            poolPoints: oneToken * 1000,
            poolFree: oneToken * 11,
            memberPoints: "\(oneToken * 100)",
            claimed: oneToken * 5,
            payouts: oneToken * 5,
            price: nil
        )

        XCTAssertEqual(result.totalRewardsDecimal, 1)
        XCTAssertEqual(result.totalStakeDecimal, 100)
        XCTAssertTrue(result.totalRewards.amount.contains("1"))
        XCTAssertTrue(result.totalStake.amount.contains("100"))
        XCTAssertNil(result.totalRewards.price)
        XCTAssertNil(result.totalStake.price)
    }

    func testClaimedRewardsAboveRecordedPayoutsIncreaseReward() throws {
        let result = try calculate(
            poolPoints: oneToken * 1000,
            poolFree: oneToken * 11,
            memberPoints: "\(oneToken * 100)",
            claimed: oneToken * 15,
            payouts: oneToken * 5,
            price: nil
        )

        XCTAssertEqual(result.totalRewardsDecimal, 2)
    }

    func testPriceDataProducesFiatValues() throws {
        let result = try calculate(
            poolPoints: oneToken * 1000,
            poolFree: oneToken * 21,
            memberPoints: "\(oneToken * 50)",
            claimed: 0,
            payouts: 0,
            price: CovCPJFixtures.price("3")
        )

        XCTAssertEqual(result.totalRewardsDecimal, 1)
        XCTAssertEqual(result.totalStakeDecimal, 50)
        XCTAssertTrue(result.totalRewards.price?.contains("3") ?? false)
        XCTAssertTrue(result.totalStake.price?.contains("150") ?? false)
    }
}
