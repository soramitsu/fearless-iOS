import Foundation
import BigInt
import RobinHood
import SSFModels
import SSFUtils
import SSFRuntimeCodingService
import XCTest
@testable import fearless

final class CovGStakingPoolFactoryTests: XCTestCase {
    func testNumericQueriesRequestCorrectStorageAndMapFirstValue() throws {
        let registry = try CovGPoolRegistry()
        let storage = CovGPoolStorage()
        let factory = try makeFactory(storage, registry)
        let queries: [(fearless.StorageCodingPath, () -> CompoundOperationWrapper<UInt32?>)] = [
            (.stakingPoolMaxPools, factory.fetchMaxStakingPoolsCount),
            (.stakingPoolMaxPoolMembers, factory.fetchMaxPoolMembers),
            (.stakingPoolCounterForBondedPools, factory.fetchCounterForBondedPools),
            (.stakingPoolMaxPoolMembersPerPool, factory.fetchMaxPoolMembersPerPool),
            (.stakingPoolLastPoolId, factory.fetchLastPoolId)
        ]
        for (path, query) in queries {
            storage.responses[path.itemName] = [Data(#""42""#.utf8)]
            XCTAssertEqual(try CovGOperationFixtures.run(query()), 42)
            XCTAssertEqual(storage.paths.last, path.itemName)
            XCTAssertEqual(storage.keys.last?.count, 32)
            storage.responses[path.itemName] = []
            XCTAssertNil(try CovGOperationFixtures.run(query()))
        }
        storage.responses[fearless.StorageCodingPath.stakingPoolMinJoinBond.itemName] = [Data(#""12345678901234567890""#.utf8)]
        XCTAssertEqual(try CovGOperationFixtures.run(factory.fetchMinJoinBondOperation()), BigUInt("12345678901234567890"))
        storage.responses[fearless.StorageCodingPath.stakingPoolMinCreateBond.itemName] = [Data(#""123""#.utf8)]
        XCTAssertEqual(try CovGOperationFixtures.run(factory.fetchMinCreateBondOperation()), 123)
    }

    func testMetadataMembersAndRewardsMapStorageResponses() throws {
        let registry = try CovGPoolRegistry()
        let storage = CovGPoolStorage()
        let factory = try makeFactory(storage, registry)
        storage.responses[fearless.StorageCodingPath.stakingPoolMetadata.itemName] = try [JSONEncoder().encode(Data("Pool name".utf8))]
        XCTAssertEqual(try CovGOperationFixtures.run(factory.fetchPoolMetadataOperation(poolId: "7")), "Pool name")
        XCTAssertEqual(storage.parameters.last, Data(#"["7"]"#.utf8))
        storage.responses[fearless.StorageCodingPath.stakingPoolMetadata.itemName] = [nil]
        XCTAssertNil(try CovGOperationFixtures.run(factory.fetchPoolMetadataOperation(poolId: "7")))
        storage.responses[fearless.StorageCodingPath.stakingPoolMembers.itemName] = [Data(#"{"poolId":"7","points":"25","unbondingEras":[]}"#.utf8)]
        let account = Data(repeating: 1, count: 32)
        let member = try XCTUnwrap(CovGOperationFixtures.run(factory.fetchStakingPoolMembers(accountId: account)))
        XCTAssertEqual(member.poolId.value, 7)
        XCTAssertEqual(member.points, 25)
        XCTAssertEqual(storage.parameters.last, try JSONEncoder().encode([account]))
        let rewards = #"{"lastRecordedRewardCounter":"3","lastRecordedTotalPayouts":"8","totalRewardsClaimed":"5"}"#
        storage.responses[fearless.StorageCodingPath.stakingPoolRewards.itemName] = [Data(rewards.utf8)]
        let value = try XCTUnwrap(CovGOperationFixtures.run(factory.fetchPoolRewardsOperation(poolId: "7")))
        XCTAssertEqual(value.lastRecordedRewardCounter, 3)
        XCTAssertEqual(value.lastRecordedTotalPayouts, 8)
        XCTAssertEqual(value.totalRewardsClaimed, 5)
    }

    func testBondedPoolsDecodeIdsAndJoinMetadata() throws {
        let registry = try CovGPoolRegistry()
        let storage = CovGPoolStorage()
        let factory = try makeFactory(storage, registry)
        let info = #"{"points":"25","state":["Open",null],"memberCounter":"2","roles":{"depositor":"AQ==","root":null,"nominator":null,"bouncer":null}}"#
        storage.responses[fearless.StorageCodingPath.bondedPools.itemName] = [nil, Data(info.utf8)]
        storage.responses[fearless.StorageCodingPath.stakingPoolMetadata.itemName] = try [JSONEncoder().encode(Data("Named pool".utf8))]
        let pools = try CovGOperationFixtures.run(factory.fetchBondedPoolsOperation())
        XCTAssertEqual(pools.count, 1)
        XCTAssertEqual(pools.first?.id, "7")
        XCTAssertEqual(pools.first?.name, "Named pool")
        XCTAssertEqual(pools.first?.info.memberCounter, 2)
        XCTAssertEqual(pools.first?.info.points, 25)
        storage.responses[fearless.StorageCodingPath.bondedPools.itemName] = [Data(info.utf8)]
        let pool = try XCTUnwrap(CovGOperationFixtures.run(factory.fetchBondedPoolOperation(poolId: "7")))
        XCTAssertEqual(pool.id, "7")
        XCTAssertEqual(pool.name, "Named pool")
        XCTAssertEqual(pool.info.state, .open)
        storage.responses[fearless.StorageCodingPath.bondedPools.itemName] = []
        XCTAssertNil(try CovGOperationFixtures.run(factory.fetchBondedPoolOperation(poolId: "7")))
        XCTAssertTrue(try CovGOperationFixtures.run(factory.fetchBondedPoolsOperation()).isEmpty)
    }

    func testMissingRuntimeAndConnectionArePropagatedForEveryQuery() throws {
        let registry = try CovGPoolRegistry()
        let storage = CovGPoolStorage()
        let factory = try makeFactory(storage, registry)
        let runtime = registry.provider
        for missingRuntime in [true, false] {
            registry.provider = missingRuntime ? nil : runtime
            registry.connection = nil
            assertFailure(factory.fetchBondedPoolsOperation())
            assertFailure(factory.fetchBondedPoolOperation(poolId: "7"))
            assertFailure(factory.fetchPoolMetadataOperation(poolId: "7"))
            assertFailure(factory.fetchMinJoinBondOperation())
            assertFailure(factory.fetchMinCreateBondOperation())
            assertFailure(factory.fetchStakingPoolMembers(accountId: Data()))
            assertFailure(factory.fetchMaxStakingPoolsCount())
            assertFailure(factory.fetchMaxPoolMembers())
            assertFailure(factory.fetchCounterForBondedPools())
            assertFailure(factory.fetchMaxPoolMembersPerPool())
            assertFailure(factory.fetchPoolRewardsOperation(poolId: "7"))
            assertFailure(factory.fetchLastPoolId())
            assertFailure(factory.fetchPendingRewards(accountId: Data()))
        }
        registry.connection = MockConnection()
        registry.provider = nil
        assertFailure(factory.fetchPendingRewards(accountId: Data()))
        XCTAssertTrue(storage.paths.isEmpty)
    }

    func testPendingRewardsDecodeU128AndTreatNilAsZero() throws {
        let registry = try CovGPoolRegistry()
        let storage = CovGPoolStorage()
        let factory = try makeFactory(storage, registry)
        for response in [nil, "0x0d000000000000000000000000000000"] as [String?] {
            let wrapper = factory.fetchPendingRewards(accountId: Data(repeating: 1, count: 32))
            let request = try XCTUnwrap(wrapper.allOperations.compactMap { $0 as? JSONRPCListOperation<String?> }.first)
            request.result = .success(response)
            XCTAssertEqual(try CovGOperationFixtures.run(wrapper), response == nil ? 0 : 13)
        }
    }

    private func makeFactory(_ storage: CovGPoolStorage, _ registry: CovGPoolRegistry) throws -> StakingPoolOperationFactory {
        try StakingPoolOperationFactory(
            chainAsset: ChainAsset(chain: CovGOperationFixtures.chain(), asset: CovGOperationFixtures.asset),
            storageRequestFactory: storage, chainRegistry: registry
        )
    }

    private func assertFailure<T>(_ wrapper: CompoundOperationWrapper<T>) {
        XCTAssertThrowsError(try CovGOperationFixtures.run(wrapper)) { XCTAssertTrue($0 is ChainRegistryError) }
    }
}

final class CovGPoolRegistry: ChainRegistryProtocolStub, @unchecked Sendable {
    var provider: RuntimeProviderProtocol?
    var connection: ChainConnection? = MockConnection()
    init(provider: RuntimeProviderProtocol? = nil) throws {
        self.provider = try provider ?? AssetHubRuntimeFixture(name: "polkadot")
        super.init()
    }

    override func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? {
        provider
    }

    override func getConnection(for _: ChainModel.Id) -> ChainConnection? {
        connection
    }
}

final class CovGPoolStorage: StorageRequestFactoryProtocol {
    var responses: [String: [Data?]] = [:]
    var paths: [String] = []
    var keys: [Data] = []
    var parameters: [Data] = []

    private func operation<T: Decodable>(
        path: fearless.StorageCodingPath, factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        configure: @escaping () throws -> Void
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        let operation = ClosureOperation<[StorageResponse<T>]> {
            _ = try factory()
            try configure()
            self.paths.append(path.itemName)
            let key = try StorageKeyFactory().key(from: path) + Data(repeating: 0, count: 8) + Data([7, 0, 0, 0])
            return try (self.responses[path.itemName] ?? []).map { data in
                try StorageResponse(key: key, data: nil, value: data.map { try JSONDecoder().decode(T.self, from: $0) })
            }
        }
        return CompoundOperationWrapper(targetOperation: operation)
    }

    func queryItems<K: Encodable, T: Decodable>(
        engine _: JSONRPCEngine, keyParams: @escaping () throws -> [K], factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        operation(path: storagePath, factory: factory) { try self.parameters.append(JSONEncoder().encode(keyParams())) }
    }

    func queryItems<T: Decodable>(
        engine _: JSONRPCEngine, keys: @escaping () throws -> [Data], factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        operation(path: storagePath, factory: factory) { try self.keys.append(contentsOf: keys()) }
    }

    func queryItemsByPrefix<T: Decodable>(
        engine _: JSONRPCEngine, keys: @escaping () throws -> [Data], factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        operation(path: storagePath, factory: factory) { try self.keys.append(contentsOf: keys()) }
    }

    func queryItems<K1: Encodable, K2: Encodable, T: Decodable>(
        engine _: JSONRPCEngine, keyParams1 _: @escaping () throws -> [K1], keyParams2 _: @escaping () throws -> [K2],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol, storagePath: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        operation(path: storagePath, factory: factory) {}
    }

    func queryItems<T: Decodable>(
        engine _: JSONRPCEngine, keyParams _: @escaping () throws -> [[NMapKeyParamProtocol]],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol, storagePath: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        operation(path: storagePath, factory: factory) {}
    }

    func queryChildItem<T: Decodable>(
        engine _: JSONRPCEngine, storageKeyParam _: @escaping () throws -> Data, childKeyParam _: @escaping () throws -> Data,
        factory _: @escaping () throws -> RuntimeCoderFactoryProtocol, mapper _: DynamicScaleDecodable, at _: Data?
    ) -> CompoundOperationWrapper<ChildStorageResponse<T>> {
        let operation = BaseOperation<ChildStorageResponse<T>>()
        operation.result = .failure(NSError(domain: "CovG.unexpectedChildQuery", code: 1))
        return CompoundOperationWrapper(targetOperation: operation)
    }
}
