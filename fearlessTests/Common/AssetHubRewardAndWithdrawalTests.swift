import XCTest
import Foundation
import BigInt
import SSFUtils
@testable import fearless

final class AssetHubRewardAndWithdrawalTests: XCTestCase {
    func testFastUnbondDependsOnValidatorHistoryAndSlashabilityAtActiveEra() throws {
        XCTAssertEqual(try period(last: nil), 2)
        XCTAssertEqual(try period(last: 72), 2)
        XCTAssertEqual(try period(last: 73), 28)
        XCTAssertEqual(try period(last: 101), 28)
        XCTAssertEqual(try period(last: nil, slashable: true), 28)
        XCTAssertThrowsError(try AssetHubUnbondingOperationFactory.unbondingEras(
            activeEra: 100,
            lastValidatorEra: nil,
            nominatorsSlashable: false,
            bondingDuration: 2,
            fastDuration: 28
        ))
    }

    func testPerbillFloorsAtEachStageAndRejectsImpossibleFractions() throws {
        XCTAssertEqual(try AssetHubRewardMath.fraction(1, of: 3, times: 3), 0)
        XCTAssertEqual(try AssetHubRewardMath.fraction(2, of: 3, times: 1_000_000_000), 666_666_666)
        XCTAssertThrowsError(try AssetHubRewardMath.fraction(1, of: 0, times: 10))
        XCTAssertThrowsError(try AssetHubRewardMath.fraction(2, of: 1, times: 10))
    }

    func testNominatorRewardUsesHistoricalPageShareAndExcludesValidatorIncentive() throws {
        let fixture = AssetHubTestSupport.self
        let exposure = try fixture.validator(fixture.first).exposure
        let overview = ValidatorExposureMetadata(total: 300, own: 100, nominatorCount: 1, pageCount: 1)
        let page = ValidatorExposurePage(others: exposure.others, pageTotal: 200)
        let amount = try AssetHubRewardMath.payout(
            allocation: .init(reward: 3000, points: 3, totalPoints: 3, commission: 200_000_000, incentive: 9000),
            exposure: .init(overview: overview, page: page, pageIndex: 0),
            account: fixture.nominator,
            validator: fixture.first
        )
        XCTAssertEqual(amount, 1601, "Perbill own share floors before nominator pool subtraction")
        XCTAssertEqual(try AssetHubRewardMath.payout(
            allocation: .init(reward: 3000, points: 3, totalPoints: 3, commission: 200_000_000, incentive: 9000),
            exposure: .init(overview: overview, page: page, pageIndex: 0),
            account: fixture.first,
            validator: fixture.first
        ), 10399)
    }

    func testOwnOnlyValidatorVirtualPageZeroAndClaimedPageIdentity() throws {
        let account = Data(repeating: 1, count: 32)
        let overview = ValidatorExposureMetadata(total: 100, own: 100, nominatorCount: 0, pageCount: 0)
        let page = ValidatorExposurePage(others: [], pageTotal: 0)
        XCTAssertEqual(try AssetHubRewardMath.payout(
            allocation: .init(reward: 500, points: 1, totalPoints: 1, commission: 0),
            exposure: .init(overview: overview, page: page, pageIndex: 0),
            account: account,
            validator: account
        ), 500)
        XCTAssertThrowsError(try AssetHubRewardMath.payout(
            allocation: .init(reward: 500, points: 1, totalPoints: 1, commission: 0),
            exposure: .init(overview: overview, page: page, pageIndex: 1),
            account: account,
            validator: account
        ))
        XCTAssertEqual(PayoutInfo(era: 12, validator: account, reward: 1, identity: nil, page: 3).page, 3)
    }

    func testPaginationRejectsRepeatedForeignUnsortedOversizedAndOverBudgetKeys() throws {
        let prefix = Data([1, 2])
        let first = prefix + Data([0])
        let second = prefix + Data([1])
        XCTAssertNoThrow(try AssetHubPagedStorage.validatePage([first, second], prefix: prefix, after: nil, remaining: 2))
        XCTAssertNoThrow(try AssetHubPagedStorage.validatePage([], prefix: prefix, after: second, remaining: 0))
        for keys in [[first, first], [second, first], [Data([9, 9, 0])], [prefix]] {
            XCTAssertThrowsError(try AssetHubPagedStorage.validatePage(keys, prefix: prefix, after: nil, remaining: 2))
        }
        XCTAssertThrowsError(try AssetHubPagedStorage.validatePage([first], prefix: prefix, after: first, remaining: 1))
        XCTAssertThrowsError(try AssetHubPagedStorage.validatePage([first, second], prefix: prefix, after: nil, remaining: 1))
    }

    func testPagingRequestEncodesNumericCountAndPinnedBlock() throws {
        let request = AssetHubPagedStorage.PageRequest(prefix: "0x1234", count: 128, start: nil, block: "0xabcd")
        let values = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [Any])
        XCTAssertEqual(values[0] as? String, "0x1234")
        XCTAssertEqual(values[1] as? Int, 128)
        XCTAssertTrue(values[2] is NSNull)
        XCTAssertEqual(values[3] as? String, "0xabcd")
    }

    func testModernSlashTupleRetainsLargeAmountAndRejectsMalformedFraction() throws {
        let slash = try JSONDecoder().decode(AssetHubValidatorSlash.self, from: Data("[\"1\",\"340282366920938463463374607431768211455\"]".utf8))
        XCTAssertEqual(slash.fraction, 1)
        XCTAssertEqual(slash.amount, (BigUInt(1) << 128) - 1)
        for json in ["[]", "[\"1000000001\",\"1\"]", "[\"1\",\"1\",\"1\"]"] {
            XCTAssertThrowsError(try JSONDecoder().decode(AssetHubValidatorSlash.self, from: Data(json.utf8)))
        }
    }

    private func period(last: UInt32?, slashable: Bool = false) throws -> UInt32 {
        try AssetHubUnbondingOperationFactory.unbondingEras(
            activeEra: 100,
            lastValidatorEra: last,
            nominatorsSlashable: slashable,
            bondingDuration: 28,
            fastDuration: 2
        )
    }
}
