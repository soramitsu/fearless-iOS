import XCTest
import SSFUtils
import BigInt
import RobinHood
@testable import fearless

final class AssetHubStorageIntegrationTests: XCTestCase {
    func testScannerContinuesShortPagesAndPinsEveryReadToOneFinalizedBlock() async throws {
        let fixture = try AssetHubStorageFixture()
        for era: UInt32 in [2, 3, 4] {
            _ = try fixture.put(.erasStakersPaged, json: "{\"others\":[],\"page_total\":\"0\"}", era: era, account: Data(repeating: 1, count: 32), page: 0)
        }
        let scanner = AssetHubPagedStorage(engine: fixture, runtime: fixture.runtime.factory, block: fixture.block, storage: AsyncStorageRequestDefault())
        var found: [ErasStakersPagedKey] = []
        try await scanner.forEachPage(path: .erasStakersPaged) { (values: [StorageResponse<ValidatorExposurePage>]) in
            found += try values.map { try scanner.decodeKey($0.key, path: .erasStakersPaged, type: .erasStakersPagedKey) }
        }
        XCTAssertEqual(Set(found.map(\.era)), [2, 3, 4])
        XCTAssertEqual(fixture.requests.filter { $0.0 == "state_getKeysPaged" }.count, 4)
        XCTAssertEqual(fixture.requests.filter { $0.0 == RPCMethod.queryStorageAt }.count, 3)
    }

    func testScannerRejectsRepeatedCursorIncompleteResponseBudgetAndCancellation() async throws {
        for fault in ["repeat", "omit", "budget", "cancel"] {
            let fixture = try AssetHubStorageFixture()
            _ = try fixture.put(.erasStakersPaged, json: "{\"others\":[],\"page_total\":\"0\"}", era: 3, account: Data(repeating: 1, count: 32), page: 0)
            fixture.repeatPage = fault == "repeat"
            fixture.omitResponse = fault == "omit"
            var scanner = AssetHubPagedStorage(engine: fixture, runtime: fixture.runtime.factory, block: fixture.block, storage: AsyncStorageRequestDefault())
            if fault == "budget" { scanner.maximumKeys = 0 }
            let operation = Task {
                if fault == "cancel" { try await Task.sleep(nanoseconds: 100_000_000) }
                try await scanner.forEachPage(path: .erasStakersPaged) { (_: [StorageResponse<ValidatorExposurePage>]) in }
            }
            if fault == "cancel" { operation.cancel() }
            do { try await operation.value; XCTFail("Accepted \(fault)") } catch {}
        }
    }

    func testQueriesDecodeNativePlainEraAndValidatorStorageAndFailOnMissingEvidence() async throws {
        let fixture = try AssetHubStorageFixture()
        let account = Data(repeating: 9, count: 32)
        _ = try fixture.put(.activeEra, json: "{\"index\":\"12\",\"start\":null}")
        _ = try fixture.put(.totalValidatorReward, json: "\"123456789\"", era: 11)
        _ = try fixture.put(.claimedRewards, json: "[\"2\",\"7\"]", era: 11, account: account)
        let queries = AssetHubStakingQueries(scanner: AssetHubPagedStorage(engine: fixture, runtime: fixture.runtime.factory, block: fixture.block, storage: AsyncStorageRequestDefault()))
        let active: ActiveEraInfo = try await queries.plain(.activeEra)
        let reward: fearless.StringScaleMapper<BigUInt> = try await queries.era(.totalValidatorReward, era: 11)
        let claimed: [fearless.StringScaleMapper<UInt32>] = try await queries.validator(.claimedRewards, era: 11, account: account)
        XCTAssertEqual(active.index, 12)
        XCTAssertEqual(reward.value, 123_456_789)
        XCTAssertEqual(claimed.map(\.value), [2, 7])
        do { let _: fearless.StringScaleMapper<BigUInt> = try await queries.era(.totalValidatorReward, era: 10); XCTFail("Missing reward") } catch {}
    }

    func testIncentiveUsesWeightedPointsWithAbsentCutoffAndLegacyWeightsBeforeCutoff() async throws {
        for name in ["polkadot", "kusama", "westend"] {
            let fixture = try AssetHubStorageFixture(name: name)
            let account = Data(repeating: 9, count: 32)
            _ = try fixture.put(.validatorIncentiveBudget, json: "\"1000\"", era: 11)
            _ = try fixture.put(.validatorIncentiveWeight, json: "\"4\"", era: 11, account: account)
            _ = try fixture.put(.sumValidatorIncentiveWeight, json: "\"10\"", era: 11)
            let queries = AssetHubStakingQueries(scanner: AssetHubPagedStorage(engine: fixture, runtime: fixture.runtime.factory, block: fixture.block, storage: AsyncStorageRequestDefault()))
            if name != "kusama" {
                _ = try fixture.put(.sumWeightedPoints, json: "\"40\"", era: 11)
                let weighted = try await queries.validatorIncentive(era: 11, account: account, points: 2)
                XCTAssertEqual(weighted, 200)
                _ = try fixture.put(.weightedPointsFormulaStartEra, json: "\"12\"")
            }
            let legacy = try await queries.validatorIncentive(era: 11, account: account, points: 2)
            XCTAssertEqual(legacy, 400)
            let zero = try await queries.validatorIncentive(era: 11, account: account, points: 0)
            XCTAssertEqual(zero, 0)
        }
    }
}
