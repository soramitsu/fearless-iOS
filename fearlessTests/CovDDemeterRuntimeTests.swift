import Foundation
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest

@testable import fearless

final class CovDDemeterRuntime: SSFRuntimeCodingService.RuntimeProviderProtocol {
    var runtimeSpecVersion: RuntimeSpecVersion = .defaultVersion
    let snapshot: RuntimeSnapshot?
    let factory: RuntimeCoderFactoryProtocol

    init(module: String = DemeterConstants.moduleName, storage: [String] = ["Pools", "TokenInfos", "UserInfos"]) throws {
        let entries = storage.map {
            RuntimeMetadataV14.StorageEntryMetadata(
                name: $0, modifier: .optional, type: .plain(PlainEntry(stringValue: "u32")), defaultValue: Data(), documentation: []
            )
        }
        let metadata = try RuntimeMetadata.v14(
            types: [], modules: [RuntimeMetadataV14.ModuleMetadata(
                name: module, storage: RuntimeMetadataV14.StorageMetadata(prefix: module, entries: entries),
                callsIndex: nil, eventsIndex: nil, constants: [], errorsIndex: nil, index: 1
            )], extrinsic: RuntimeMetadataV14.ExtrinsicMetadata(type: 0, version: 4, signedExtensions: [])
        )
        let catalog = try TypeRegistryCatalog.createFromTypeDefinition(
            Data(#"{"types":{}}"#.utf8), runtimeMetadata: metadata, usedRuntimePaths: [:]
        )
        factory = TestRuntimeCoderFactory(catalog: catalog, specVersion: 1, txVersion: 1, metadata: metadata)
        snapshot = RuntimeSnapshot(typeRegistryCatalog: catalog, specVersion: 1, txVersion: 1, metadata: metadata)
    }

    func setup() {}
    func setupHot() {}
    func cleanup() {}
    func readySnapshot() async throws -> RuntimeSnapshot { try XCTUnwrap(snapshot) }
    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol { factory }
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> { ClosureOperation { self.factory } }
}

final class CovDDemeterStorage: AsyncStorageRequestFactory {
    var error: Error?
    private let base = Data(repeating: 1, count: 32)
    private let pool = Data(repeating: 2, count: 32)
    private let reward = Data(repeating: 3, count: 32)

    private func responses<T: Decodable>(path: fearless.StorageCodingPath) throws -> [StorageResponse<T>] {
        if let error { throw error }
        let object: Any
        let key: Data
        switch path {
        case .demeterPools:
            key = Data(repeating: 0, count: 32) + pool + reward
            object = [[
                "baseAsset": ["code": base.base64EncodedString()], "isFarm": true, "isCore": false, "isRemoved": false,
                "multiplier": "2", "depositFee": "3", "totalTokensInPool": "400", "rewards": "5", "rewardsToBeDistributed": "6"
            ]]
        case .demeterTokenInfos:
            key = Data(repeating: 0, count: 32) + reward
            object = ["farmsTotalMultiplier": "7", "stakingTotalMultiplier": "8", "tokenPerBlock": "9", "farmsAllocation": "10", "stakingAllocation": "11"]
        case .demeterUserInfos:
            key = base
            object = [[
                "baseAsset": ["code": base.base64EncodedString()], "poolAsset": ["code": pool.base64EncodedString()],
                "rewardAsset": ["code": reward.base64EncodedString()], "isFarm": true, "pooledTokens": "12", "rewards": "13"
            ]]
        default: throw CovDTestError.offline
        }
        let data = try JSONSerialization.data(withJSONObject: object)
        let value = try JSONDecoder().decode(T.self, from: data)
        return [StorageResponse(key: key, data: data, value: value), StorageResponse(key: Data([1]), data: nil, value: nil)]
    }

    func queryItems<T: Decodable>(
        engine _: JSONRPCEngine, keyParams _: [any Encodable], factory _: RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath, at _: Data?
    ) async throws -> [StorageResponse<T>] { try responses(path: storagePath) }

    func queryItems<T: Decodable>(
        engine _: JSONRPCEngine, keys _: [Data], factory _: RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath, at _: Data?
    ) async throws -> [StorageResponse<T>] { try responses(path: storagePath) }

    func queryItems<T: Decodable>(
        engine _: JSONRPCEngine, keyParams _: [[[any NMapKeyParamProtocol]]], factory _: RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath, at _: Data?
    ) async throws -> [StorageResponse<T>] { try responses(path: storagePath) }

    func queryItemsByPrefix<T: Decodable>(
        engine _: JSONRPCEngine, keys _: [Data], factory _: RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath, at _: Data?
    ) async throws -> [StorageResponse<T>] { try responses(path: storagePath) }

    func queryItemsByPrefix<T: Decodable>(
        engine _: JSONRPCEngine, keyParams _: [any Encodable], factory _: RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath, at _: Data?
    ) async throws -> [StorageResponse<T>] { try responses(path: storagePath) }

    func queryChildItem<T: Decodable>(
        engine _: JSONRPCEngine, storageKeyParam _: Data, childKeyParam _: Data, factory _: RuntimeCoderFactoryProtocol,
        mapper _: DynamicScaleDecodable, at _: Data?
    ) async throws -> ChildStorageResponse<T> { throw CovDTestError.offline }

    func queryWorkersResult(for _: [Data], at _: Data?, engine _: JSONRPCEngine) async throws -> [[StorageUpdate]] { [] }
}

final class CovDDemeterRuntimeTests: XCTestCase {
    func testSnapshotDecodesPoolsTokensAndPositionsFromRuntimeStorage() async throws {
        let registry = CovDRegistryStub()
        registry.runtime = try CovDDemeterRuntime()
        registry.connection = MockConnection()
        let service = try XCTUnwrap(DemeterRuntimeService(
            wallet: CovDFixtures.wallet(), chain: CovDFixtures.soraChain(), chainRegistry: registry, storageFactory: CovDDemeterStorage()
        ))
        let snapshot = try await service.snapshot()
        XCTAssertTrue(snapshot.capabilities.canBrowse)
        XCTAssertFalse(snapshot.capabilities.canMutate)
        XCTAssertEqual(snapshot.pools.count, 1)
        let pool = try XCTUnwrap(snapshot.pools.first)
        XCTAssertEqual(pool.multiplier, "2")
        XCTAssertEqual(pool.depositFee, "3")
        XCTAssertEqual(pool.totalTokensInPool, "400")
        XCTAssertEqual(pool.rewards, "5")
        XCTAssertEqual(pool.rewardsToBeDistributed, "6")
        XCTAssertFalse(pool.isCore)
        XCTAssertFalse(pool.isRemoved)
        XCTAssertTrue(pool.identity.isFarm)
        XCTAssertEqual(pool.identity.poolAssetId, "0x" + String(repeating: "02", count: 32))
        XCTAssertEqual(snapshot.positions.count, 1)
        XCTAssertEqual(snapshot.positions.first?.identity, pool.identity)
        XCTAssertEqual(snapshot.positions.first?.pooledTokens, "12")
        XCTAssertEqual(snapshot.positions.first?.rewards, "13")
        let token = try XCTUnwrap(snapshot.rewardTokens[pool.identity.rewardAssetId])
        XCTAssertEqual(token.farmsTotalMultiplier, "7")
        XCTAssertEqual(token.stakingTotalMultiplier, "8")
        XCTAssertEqual(token.tokenPerBlock, "9")
        XCTAssertEqual(token.farmsAllocation, "10")
        XCTAssertEqual(token.stakingAllocation, "11")
    }

    func testRuntimeWithoutPalletOrRequiredStorageHasHonestCapabilities() async throws {
        for runtime in [try CovDDemeterRuntime(module: "Other"), try CovDDemeterRuntime(storage: ["Pools"])] {
            let registry = CovDRegistryStub()
            registry.runtime = runtime
            registry.connection = MockConnection()
            let service = try XCTUnwrap(DemeterRuntimeService(
                wallet: CovDFixtures.wallet(), chain: CovDFixtures.soraChain(), chainRegistry: registry, storageFactory: CovDDemeterStorage()
            ))
            let snapshot = try await service.snapshot()
            XCTAssertFalse(snapshot.capabilities.canBrowse)
            XCTAssertNotNil(snapshot.capabilities.unavailableReason)
            XCTAssertTrue(snapshot.pools.isEmpty)
            XCTAssertTrue(snapshot.positions.isEmpty)
        }
    }

    func testWatchWalletOmitsPositionsAndStorageFailurePropagates() async throws {
        let registry = CovDRegistryStub()
        registry.runtime = try CovDDemeterRuntime()
        registry.connection = MockConnection()
        let storage = CovDDemeterStorage()
        let service = try XCTUnwrap(DemeterRuntimeService(
            wallet: CovDFixtures.wallet(substrate: false), chain: CovDFixtures.soraChain(), chainRegistry: registry, storageFactory: storage
        ))
        let snapshot = try await service.snapshot()
        XCTAssertEqual(snapshot.pools.count, 1)
        XCTAssertTrue(snapshot.positions.isEmpty)
        storage.error = CovDTestError.offline
        do {
            _ = try await service.snapshot()
            XCTFail("Expected storage failure")
        } catch { XCTAssertEqual(error as? CovDTestError, .offline) }
    }
}
