import Foundation
import RobinHood
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

final class CovGPerformerTests: XCTestCase {
    func testNMapRequestsResolveSingleAndMultipleValues() async throws {
        let fixture = try AssetHubStorageFixture()
        fixture.allowsUnpinnedReads = true
        let account = Data(repeating: 4, count: 32)
        _ = try fixture.put(.claimedRewards, json: #"["1","2"]"#, era: 5, account: account)
        let performer = StorageRequestPerformerDefault(runtimeService: fixture.runtime, connection: fixture)
        let params: [[any NMapKeyParamProtocol]] = [
            [NMapKeyParam(value: fearless.StringScaleMapper(value: UInt32(5)))], [NMapKeyParam(value: account)],
        ]
        let single: [fearless.StringScaleMapper<UInt32>]? = try await performer.performSingle(
            CovGPerformerRequest(parametersType: .nMap(params: params), storagePath: .claimedRewards)
        )
        XCTAssertEqual(single?.map(\.value), [1, 2])
        let many: [[fearless.StringScaleMapper<UInt32>]?] = try await performer.performMultiple(
            CovGPerformerMultipleRequest(parametersType: .multipleNMap(params: params), storagePath: .claimedRewards)
        )
        XCTAssertEqual(many.count, 1)
        XCTAssertEqual(many.first??.map(\.value), [1, 2])
    }

    func testPrefixRequestMapsDecodedKeysToValues() async throws {
        let runtime = try AssetHubRuntimeFixture(name: "polkadot")
        let key = try StorageKeyFactory().createStorageKey(
            moduleName: "NominationPools", storageName: "Metadata", key: Data([7, 0, 0, 0]), hasher: .twox64Concat
        )
        let engine = CovGRPCEngine()
        engine.responses[RPCMethod.getStorageKeysPaged] = try JSONEncoder().encode([key.toHex(includePrefix: true)])
        engine.responses[RPCMethod.queryStorageAt] = try JSONSerialization.data(withJSONObject: [
            ["block": "0x00", "changes": [[key.toHex(includePrefix: true), "0x0c616263"]]],
        ])
        let performer = StorageRequestPerformerDefault(runtimeService: runtime, connection: engine)
        let values: [String: JSON]? = try await performer.performPrefix(CovGPerformerPrefixRequest())
        XCTAssertEqual(values?.keys.sorted(), ["7"])
        XCTAssertNotNil(values?["7"])
        XCTAssertEqual(engine.requests.map(\.0), [RPCMethod.getStorageKeysPaged, RPCMethod.queryStorageAt])
    }

    func testSingleRequestRejectsMoreThanOneStorageResponse() async throws {
        let runtime = try AssetHubRuntimeFixture(name: "polkadot")
        let key = try StorageKeyFactory().key(from: .currentEra)
        let engine = CovGRPCEngine()
        engine.responses[RPCMethod.queryStorageAt] = try JSONSerialization.data(withJSONObject: [
            ["block": "0x00", "changes": [[key.toHex(includePrefix: true), "0x2a000000"], ["0x01", "0x2b000000"]]],
        ])
        let performer = StorageRequestPerformerDefault(runtimeService: runtime, connection: engine)
        do {
            let value: fearless.StringScaleMapper<UInt32>? = try await performer.performSingle(
                CovGPerformerRequest(parametersType: .simple, storagePath: .currentEra)
            )
            XCTFail("Expected invalid response, got \(String(describing: value))")
        } catch {
            guard case StorageResponseValueExtractorError.invalidResponse = error else {
                return XCTFail("Wrong error \(error)")
            }
        }
        XCTAssertEqual(CachedStorageRequestTrigger.onAll, [.onCache, .onPerform])
        XCTAssertFalse(CachedStorageRequestTrigger.onCache.contains(.onPerform))
    }
}

private struct CovGPerformerRequest: StorageRequest {
    let parametersType: StorageRequestParametersType
    let storagePath: fearless.StorageCodingPath
}

private struct CovGPerformerMultipleRequest: MultipleRequest {
    let parametersType: MultipleStorageRequestParametersType
    let storagePath: fearless.StorageCodingPath
}

private struct CovGPerformerPrefixRequest: PrefixRequest {
    let storagePath = fearless.StorageCodingPath.stakingPoolMetadata
    let keyType = MapKeyType.u32
}
