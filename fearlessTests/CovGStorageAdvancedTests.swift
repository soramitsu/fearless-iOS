@testable import fearless
import Foundation
import RobinHood
import SSFRuntimeCodingService
import SSFUtils
import XCTest

final class CovGStorageAdvancedTests: XCTestCase {
    func testStorageRequestsSplitLargeKeyListsAndPreserveInputOrder() throws {
        let engine = CovGRPCEngine()
        let keys = (0 ... 1000).map { value -> Data in var value = UInt32(value).littleEndian; return withUnsafeBytes(of: &value) { Data($0) } }
        engine.handler = { method, payload in
            XCTAssertEqual(method, RPCMethod.queryStorageAt)
            let params = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(payload)) as? [Any])
            let strings = try XCTUnwrap(params.first as? [String])
            let changes = strings.reversed().map { [$0, "0x2a000000"] }
            return try JSONSerialization.data(withJSONObject: [["block": "0x00", "changes": changes]])
        }
        let runtime = try RuntimeCodingServiceStub.createWestendCodingFactory()
        let factory = StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: OperationManager())
        let wrapper: CompoundOperationWrapper<[StorageResponse<fearless.StringScaleMapper<UInt32>>]> = factory.queryItems(
            engine: engine, keys: { keys }, factory: { runtime }, storagePath: .currentEra
        )
        let result = try CovGOperationFixtures.run(wrapper)
        XCTAssertEqual(result.map(\.key), keys)
        XCTAssertTrue(result.allSatisfy { $0.value?.value == 42 })
        XCTAssertEqual(engine.requests.count, 2)
        let empty: CompoundOperationWrapper<[StorageResponse<String>]> = factory.queryItems(
            engine: engine, keys: { [] }, factory: { runtime }, storagePath: .currentEra
        )
        XCTAssertTrue(try CovGOperationFixtures.run(empty).isEmpty)
        XCTAssertEqual(engine.requests.count, 2)
    }

    func testPrefixQueriesFetchReturnedKeysAndPropagateKeyFactoryErrors() throws {
        let engine = CovGRPCEngine()
        let runtime = try RuntimeCodingServiceStub.createWestendCodingFactory()
        let key = try StorageKeyFactory().key(from: .currentEra)
        engine.responses[RPCMethod.getStorageKeysPaged] = try JSONEncoder().encode([key.toHex(includePrefix: true)])
        engine.responses[RPCMethod.queryStorageAt] = try JSONSerialization.data(withJSONObject: [
            ["block": "0x00", "changes": [[key.toHex(includePrefix: true), "0x2a000000"]]],
        ])
        let factory = StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: OperationManager())
        let wrapper: CompoundOperationWrapper<[StorageResponse<fearless.StringScaleMapper<UInt32>>]> = factory.queryItemsByPrefix(
            engine: engine, keys: { [key] }, factory: { runtime }, storagePath: .currentEra
        )
        let response = try CovGOperationFixtures.run(wrapper)
        XCTAssertEqual(response.first?.key, key)
        XCTAssertEqual(response.first?.value?.value, 42)
        let params = try XCTUnwrap(engine.requests.first?.1)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: params) as? [AnyHashable], [key.toHex(includePrefix: true), 1000])
        let invalid: CompoundOperationWrapper<[StorageResponse<String>]> = factory.queryItemsByPrefix(
            engine: engine, keys: { throw NSError(domain: "CovG.keys", code: 94) }, factory: { runtime }, storagePath: .currentEra
        )
        XCTAssertThrowsError(try CovGOperationFixtures.run(invalid)) { XCTAssertEqual(($0 as NSError).code, 94) }
    }

    func testChildStorageDecodesCrowdloanContributionAndPreservesAbsentValue() throws {
        let engine = CovGRPCEngine()
        let runtime = try RuntimeCodingServiceStub.createWestendCodingFactory()
        let factory = StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: OperationManager())
        let bytes = Data([53]) + Data(repeating: 0, count: 15) + Data([8, 1, 2])
        engine.responses[RPCMethod.getChildStorageAt] = try JSONEncoder().encode(bytes.toHex(includePrefix: true))
        let wrapper: CompoundOperationWrapper<ChildStorageResponse<CrowdloanContribution>> = factory.queryChildItem(
            engine: engine, storageKeyParam: { Data([1]) }, childKeyParam: { Data([2]) }, factory: { runtime }, mapper: CrowdloanContributionMapper()
        )
        let result = try CovGOperationFixtures.run(wrapper)
        XCTAssertEqual(result.storageKey, Data([1]))
        XCTAssertEqual(result.childKey, Data([2]))
        XCTAssertEqual(result.data, bytes)
        XCTAssertEqual(result.value?.balance, 53)
        XCTAssertEqual(result.value?.memo, Data([1, 2]))
        XCTAssertEqual(engine.requests.first?.1, Data(#"["0x02","0x01"]"#.utf8))
        engine.responses[RPCMethod.getChildStorageAt] = Data("null".utf8)
        let absent: CompoundOperationWrapper<ChildStorageResponse<CrowdloanContribution>> = factory.queryChildItem(
            engine: engine, storageKeyParam: { Data([1]) }, childKeyParam: { Data([2]) }, factory: { runtime }, mapper: CrowdloanContributionMapper()
        )
        XCTAssertNil(try CovGOperationFixtures.run(absent).value)
        let invalid: CompoundOperationWrapper<ChildStorageResponse<CrowdloanContribution>> = factory.queryChildItem(
            engine: engine, storageKeyParam: { throw NSError(domain: "CovG.child", code: 95) },
            childKeyParam: { Data([2]) }, factory: { runtime }, mapper: CrowdloanContributionMapper()
        )
        XCTAssertThrowsError(try CovGOperationFixtures.run(invalid)) { XCTAssertEqual(($0 as NSError).code, 95) }
    }

    func testAsyncChildQueriesAndPrefixValueExtraction() async throws {
        let engine = CovGRPCEngine()
        let runtime = try AssetHubRuntimeFixture(name: "polkadot")
        let factory = AsyncStorageRequestDefault()
        let bytes = Data([53]) + Data(repeating: 0, count: 15) + Data([8, 1, 2])
        engine.responses[RPCMethod.getChildStorageAt] = try JSONEncoder().encode(bytes.toHex(includePrefix: true))
        let value: ChildStorageResponse<CrowdloanContribution> = try await factory.queryChildItem(
            engine: engine, storageKeyParam: Data([1]), childKeyParam: Data([2]), factory: runtime.factory, mapper: CrowdloanContributionMapper()
        )
        XCTAssertEqual(value.value?.balance, 53)
        engine.responses[RPCMethod.getChildStorageAt] = Data("null".utf8)
        let absent: ChildStorageResponse<CrowdloanContribution> = try await factory.queryChildItem(
            engine: engine, storageKeyParam: Data([1]), childKeyParam: Data([2]), factory: runtime.factory, mapper: CrowdloanContributionMapper()
        )
        XCTAssertNil(absent.data)
        XCTAssertNil(absent.value)
        let key = try StorageKeyFactory().key(from: .bondedPools) + Data(repeating: 0, count: 8) + Data([7, 0, 0, 0])
        let extractor = PrefixStorageResponseValueExtractor(runtimeService: runtime)
        let response = StorageResponse(key: key, data: nil, value: "Pool")
        let values: [String: String]? = try await extractor.extractValue(request: CovGPrefixRequest(), storageResponse: [response])
        XCTAssertEqual(values, ["7": "Pool"])
        let empty: [String: String]? = try await extractor.extractValue(request: CovGPrefixRequest(), storageResponse: [StorageResponse<String>]())
        XCTAssertEqual(empty, [:])
    }
}

private struct CovGPrefixRequest: PrefixRequest {
    let storagePath = fearless.StorageCodingPath.bondedPools
    let keyType = MapKeyType.u32
}
