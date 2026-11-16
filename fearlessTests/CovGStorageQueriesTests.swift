import Foundation
import RobinHood
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

final class CovGStorageQueriesTests: XCTestCase {
    func testDoubleMapQueryEncodesBothKeysAndPreservesMissingValue() throws {
        let runtime = try RuntimeCodingServiceStub.createWestendCodingFactory()
        let account = Data(repeating: 7, count: 32)
        let keyFactory = StorageKeyFactory()
        let expected = try keyFactory.createStorageKey(
            moduleName: "Staking", storageName: "ErasStakers", key1: Data([5, 0, 0, 0]), hasher1: .twox64Concat,
            key2: account, hasher2: .twox64Concat
        )
        let engine = CovGRPCEngine()
        engine.handler = { method, payload in
            XCTAssertEqual(method, RPCMethod.queryStorageAt)
            let params = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(payload)) as? [Any])
            let keys = try XCTUnwrap(params.first as? [String])
            XCTAssertEqual(keys, [expected.toHex(includePrefix: true)])
            return try JSONSerialization.data(withJSONObject: [["block": "0x00", "changes": keys.map { [$0, NSNull()] }]])
        }
        let factory = StorageRequestFactory(remoteFactory: keyFactory, operationManager: OperationManager())
        let wrapper: CompoundOperationWrapper<[StorageResponse<JSON>]> = factory.queryItems(
            engine: engine, keyParams1: { [fearless.StringScaleMapper(value: UInt32(5))] }, keyParams2: { [account] },
            factory: { runtime }, storagePath: .erasStakers
        )
        let result = try CovGOperationFixtures.run(wrapper)
        XCTAssertEqual(result.map(\.key), [expected])
        XCTAssertNil(result.first?.data)
        XCTAssertNil(result.first?.value)
        let failing: CompoundOperationWrapper<[StorageResponse<JSON>]> = factory.queryItems(
            engine: engine, keyParams1: { () throws -> [String] in throw NSError(domain: "CovG.double", code: 70) }, keyParams2: { [account] },
            factory: { runtime }, storagePath: .erasStakers
        )
        XCTAssertThrowsError(try CovGOperationFixtures.run(failing)) { XCTAssertEqual(($0 as NSError).code, 70) }
    }

    func testAsyncExtensionQueriesMapNMapAndRawKeysWithoutPinnedBlock() async throws {
        let fixture = try AssetHubStorageFixture()
        fixture.allowsUnpinnedReads = true
        let account = Data(repeating: 1, count: 32)
        let nominatorsKey = try fixture.put(.nominators, json: #"{"targets":[],"submitted_in":"9","suppressed":false}"#, account: account)
        let claimedKey = try fixture.put(.claimedRewards, json: #"["1","2"]"#, era: 5, account: account)
        let eraKey = try fixture.put(.currentEra, json: #""42""#)
        let factory: AsyncStorageRequestFactory = AsyncStorageRequestDefault()

        let mapped: [StorageResponse<JSON>] = try await factory.queryItems(
            engine: fixture, keyParams: [account], factory: fixture.runtime.factory, storagePath: .nominators
        )
        XCTAssertEqual(mapped.map(\.key), [nominatorsKey])
        XCTAssertNotNil(mapped.first?.value)
        XCTAssertNotNil(mapped.first?.data)

        let params: [[[any NMapKeyParamProtocol]]] = [[
            [NMapKeyParam(value: fearless.StringScaleMapper(value: UInt32(5)))], [NMapKeyParam(value: account)],
        ]]
        let claimed: [StorageResponse<[fearless.StringScaleMapper<UInt32>]>] = try await factory.queryItems(
            engine: fixture, keyParams: params, factory: fixture.runtime.factory, storagePath: .claimedRewards
        )
        XCTAssertEqual(claimed.map(\.key), [claimedKey])
        XCTAssertEqual(claimed.first?.value?.map(\.value), [1, 2])

        let era: [StorageResponse<fearless.StringScaleMapper<UInt32>>] = try await factory.queryItems(
            engine: fixture, keys: [eraKey], factory: fixture.runtime.factory, storagePath: .currentEra
        )
        XCTAssertEqual(era.first?.value?.value, 42)
        XCTAssertTrue(fixture.requests.allSatisfy { $0.0 == RPCMethod.queryStorageAt })
    }

    func testAsyncPrefixExtensionPagesKeysBeforeReadingValues() async throws {
        let runtime = try RuntimeCodingServiceStub.createWestendCodingFactory()
        let prefix = try StorageKeyFactory().key(from: .currentEra)
        let engine = CovGRPCEngine()
        engine.responses[RPCMethod.getStorageKeysPaged] = try JSONEncoder().encode([prefix.toHex(includePrefix: true)])
        engine.responses[RPCMethod.queryStorageAt] = try JSONSerialization.data(withJSONObject: [
            ["block": "0x00", "changes": [[prefix.toHex(includePrefix: true), "0x2a000000"]]],
        ])
        let factory: AsyncStorageRequestFactory = AsyncStorageRequestDefault()
        let values: [StorageResponse<fearless.StringScaleMapper<UInt32>>] = try await factory.queryItemsByPrefix(
            engine: engine, keys: [prefix], factory: runtime, storagePath: .currentEra
        )
        XCTAssertEqual(values.map(\.key), [prefix])
        XCTAssertEqual(values.first?.value?.value, 42)
        XCTAssertEqual(engine.requests.map(\.0), [RPCMethod.getStorageKeysPaged, RPCMethod.queryStorageAt])
        let paging = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(engine.requests.first?.1)) as? [Any])
        XCTAssertEqual(paging.first as? String, prefix.toHex(includePrefix: true))
        XCTAssertEqual(paging.last as? Int, 1000)
    }
}
