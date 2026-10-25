import BigInt
import MocksBasket
import SSFChainConnection
import SSFChainRegistry
import SSFCrypto
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest

@testable import SSFStorageQueryKit

final class StorageRequestPerformerTests: XCTestCase {
    private var polkadotRuntimeService: RuntimeProviderProtocol!

    private let chain = ChainModel(
        rank: 0,
        disabled: false,
        chainId: "91b171bb158e2d3848fa23a9f1c25182fb8e20313b2c1eb49219da7a70ce90c3",
        paraId: nil,
        name: "Polkadot",
        xcm: nil,
        nodes: [],
        addressPrefix: 0,
        icon: nil,
        iosMinAppVersion: nil,
        identityChain: nil
    )

    private let timestampRequest = StorageRequestMock(
        parametersType: .simple,
        storagePath: StoragePathMock.custom(moduleName: "timestamp", itemName: "now")
    )
    private let expectedTimestamp = "1707982452001"
    private let timestampValue = "0x21f5afab8d010000"

    override func setUp() async throws {
        try await super.setUp()
        if polkadotRuntimeService == nil {
            polkadotRuntimeService = try await PolkadotRuntimeProvider().buildRuntimeProvider()
        }
    }

    // MARK: - performSingle

    func testSimpleSingleRequest() async throws {
        let performer = try await createPerformer(answering: timestampRequest, with: timestampValue)

        let timestamp: String? = try await performer.performSingle(timestampRequest, chain: chain)

        XCTAssertEqual(timestamp, expectedTimestamp)
    }

    func testEncodedSingleRequest() async throws {
        let expectedAccount = try AddressFactory.accountId(
            from: "12zcF9m6QpUaGeJrrKYRGubZuxa9YyuVRTjpXGyVNsCpzspY",
            chainFormat: .sfSubstrate(0)
        )
        let request = StorageRequestMock(
            parametersType: .encodable(param: expectedAccount),
            storagePath: StoragePathMock.custom(moduleName: "staking", itemName: "bonded")
        )
        let performer = try await createPerformer(
            answering: request,
            with: "0x582bdd02e8b7e3a97da353f92954db770676e7f07eddf2d08cb9f2430aaf4429"
        )

        let account: AccountId? = try await performer.performSingle(request, chain: chain)

        XCTAssertEqual(account, expectedAccount)
    }

    func testNMapSingleRequest() async throws {
        let account = try AddressFactory.accountId(
            from: "1zugcag7cJVBtVRnFxv5Qftn7xKAnR6YJ9x4x3XLgGgmNnS",
            chainFormat: .sfSubstrate(0)
        )
        let request = StorageRequestMock(
            parametersType: .nMap(params: [
                [NMapKeyParam(value: "1353")],
                [NMapKeyParam(value: account)],
            ]),
            storagePath: StoragePathMock.custom(
                moduleName: "staking",
                itemName: "erasValidatorPrefs"
            )
        )
        // Compact commission 77000000, not blocked
        let performer = try await createPerformer(answering: request, with: "0x02b55b1200")

        let result: ValidatorPrefs? = try await performer.performSingle(request, chain: chain)

        XCTAssertEqual(result, ValidatorPrefs(commission: 77_000_000, blocked: false))
    }

    // MARK: - performSingle with cache options

    func testCacheOnAllSingleYieldsTheCachedAndTheRemoteValue() async throws {
        let performer = try await createPerformer(answering: timestampRequest, with: timestampValue)
        try await fetchUntilCached(
            timestampRequest,
            performer: performer,
            expected: expectedTimestamp
        )

        let responses = try await collect(
            await performer.performSingle(timestampRequest, withCacheOptions: .onAll, chain: chain)
                as AsyncThrowingStream<CachedStorageResponse<String>, Error>
        )

        XCTAssertEqual(responses.map(\.value), [expectedTimestamp, expectedTimestamp])
        XCTAssertEqual(responses.map(\.type), [.cache, .remote])
    }

    func testCacheWithBothOptionsByHandIsTheSameAsOnAll() async throws {
        let performer = try await createPerformer(answering: timestampRequest, with: timestampValue)
        try await fetchUntilCached(
            timestampRequest,
            performer: performer,
            expected: expectedTimestamp
        )

        let responses = try await collect(
            await performer.performSingle(
                timestampRequest,
                withCacheOptions: [.onPerform, .onCache],
                chain: chain
            ) as AsyncThrowingStream<CachedStorageResponse<String>, Error>
        )

        XCTAssertEqual(responses.map(\.type), [.cache, .remote])
    }

    func testCacheOnCacheSingleYieldsOnlyTheCachedValue() async throws {
        let performer = try await createPerformer(answering: timestampRequest, with: timestampValue)
        try await fetchUntilCached(
            timestampRequest,
            performer: performer,
            expected: expectedTimestamp
        )

        let responses = try await collect(
            await performer.performSingle(
                timestampRequest,
                withCacheOptions: .onCache,
                chain: chain
            )
                as AsyncThrowingStream<CachedStorageResponse<String>, Error>
        )

        XCTAssertEqual(responses.map(\.value), [expectedTimestamp])
        XCTAssertEqual(responses.map(\.type), [.cache])
    }

    func testCacheOnPerformSingleYieldsOnlyTheRemoteValue() async throws {
        let performer = try await createPerformer(answering: timestampRequest, with: timestampValue)

        let responses = try await collect(
            await performer.performSingle(
                timestampRequest,
                withCacheOptions: .onPerform,
                chain: chain
            )
                as AsyncThrowingStream<CachedStorageResponse<String>, Error>
        )

        XCTAssertEqual(responses.map(\.value), [expectedTimestamp])
        XCTAssertEqual(responses.map(\.type), [.remote])
    }

    // MARK: - performMultiple

    func testEncodedMultipleRequestIsKeyedByTheStorageKeyParameter() async throws {
        let stashes = (0 ..< 3).map { account(byte: UInt8(0x10 + $0)) }
        let controllers = (0 ..< 3).map { account(byte: UInt8(0x20 + $0)) }
        let path = StoragePathMock.custom(moduleName: "Staking", itemName: "Bonded")
        let codingFactory = try await polkadotRuntimeService.fetchCoderFactory()
        let keys = try MapKeyEncodingWorker(
            codingFactory: codingFactory,
            path: path,
            storageKeyFactory: StorageKeyFactory(),
            keyParams: stashes
        ).performEncoding()
        let performer = createPerformer(with: [StorageUpdate(
            blockHash: nil,
            changes: zip(keys, controllers).map { [
                $0.toHex(includePrefix: true),
                $1.toHex(includePrefix: true),
            ] }
        )])
        let request = MultipleStorageRequstMock(
            parametersType: .multipleEncodable(params: stashes),
            storagePath: path
        )

        let bonded: [AccountId: AccountId]? = try await performer.performMultiple(
            request,
            chain: chain
        )

        XCTAssertEqual(bonded, Dictionary(uniqueKeysWithValues: zip(stashes, controllers)))
    }

    func testEncodedMultipleRequestOnAllYieldsTheCachedAndTheRemoteValues() async throws {
        let stashes = (0 ..< 3).map { account(byte: UInt8(0x40 + $0)) }
        let controllers = (0 ..< 3).map { account(byte: UInt8(0x50 + $0)) }
        let path = StoragePathMock.custom(moduleName: "Staking", itemName: "Bonded")
        let codingFactory = try await polkadotRuntimeService.fetchCoderFactory()
        let keys = try MapKeyEncodingWorker(
            codingFactory: codingFactory,
            path: path,
            storageKeyFactory: StorageKeyFactory(),
            keyParams: stashes
        ).performEncoding()
        let performer = createPerformer(with: [StorageUpdate(
            blockHash: nil,
            changes: zip(keys, controllers).map { [
                $0.toHex(includePrefix: true),
                $1.toHex(includePrefix: true),
            ] }
        )])
        let request = MultipleStorageRequstMock(
            parametersType: .multipleEncodable(params: stashes),
            storagePath: path
        )
        let expected = Dictionary(uniqueKeysWithValues: zip(stashes, controllers))

        // The remote response is saved in the background; wait until all of it is there.
        for _ in 0 ..< 50 {
            let _: [AccountId: AccountId]? = try await performer.performMultiple(
                request,
                chain: chain
            )
            let cached = try await collect(
                await performer.performMultiple(request, withCacheOptions: .onCache, chain: chain)
                    as AsyncThrowingStream<CachedStorageResponse<[AccountId: AccountId]>, Error>
            )
            if cached.first?.value == expected {
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        let responses = try await collect(
            await performer.performMultiple(request, withCacheOptions: .onAll, chain: chain)
                as AsyncThrowingStream<CachedStorageResponse<[AccountId: AccountId]>, Error>
        )

        XCTAssertEqual(responses.map(\.type), [.cache, .remote])
        XCTAssertEqual(responses.map(\.value), [expected, expected])
    }

    func testNMapMultipleRequestUsesFinalAccountComponent() async throws {
        let (request, performer, expected) = try await nMapFixture()
        let values: [AccountId: ValidatorPrefs]? = try await performer.performMultiple(
            request,
            chain: chain
        )
        XCTAssertEqual(values, expected)
    }

    func testNMapMultipleCachedAndRemoteKeysAgree() async throws {
        let (request, performer, expected) = try await nMapFixture()
        // Populate the cache, then compare the cached and freshly decoded account keys.
        var cachedValues: [AccountId: ValidatorPrefs]?
        for _ in 0 ..< 50 {
            let _: [AccountId: ValidatorPrefs]? = try await performer.performMultiple(
                request,
                chain: chain
            )
            let cached = try await collect(
                await performer.performMultiple(request, withCacheOptions: .onCache, chain: chain)
                    as AsyncThrowingStream<
                        CachedStorageResponse<[AccountId: ValidatorPrefs]>,
                        Error
                    >
            )
            cachedValues = cached.first?.value
            if cachedValues == expected {
                break
            }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertEqual(cachedValues, expected)
        let responses = try await collect(
            await performer.performMultiple(request, withCacheOptions: .onAll, chain: chain)
                as AsyncThrowingStream<CachedStorageResponse<[AccountId: ValidatorPrefs]>, Error>
        )
        XCTAssertEqual(responses.map(\.type), [.cache, .remote])
        XCTAssertEqual(responses.map(\.value), [expected, expected])
    }

    func testAccountKeyRejectsTruncatedStoragePrefix() async throws {
        let extractor = StorageKeyDataExtractor(runtimeService: polkadotRuntimeService)
        do {
            let _: AccountId = try await extractor.extractKey(
                storageKey: account(byte: 0x11),
                storagePath: StoragePathMock.custom(moduleName: "Staking", itemName: "Bonded"),
                type: .accountId
            )
            XCTFail("A bare account is not a complete storage key")
        } catch StorageKeyEncodingOperationError.incompatibleStorageType {
            // Expected: do not mistake the path prefix or a truncated digest for an account.
        }
    }

    private func nMapFixture() async throws -> (
        MultipleStorageRequstMock, StorageRequestPerformerDefault, [AccountId: ValidatorPrefs]
    ) {
        let stashes = [account(byte: 0x61), account(byte: 0x62)]
        let path = StoragePathMock.custom(moduleName: "Staking", itemName: "ErasValidatorPrefs")
        let params: [[[any NMapKeyParamProtocol]]] = [[
            [NMapKeyParam(value: "1353"), NMapKeyParam(value: "1353")],
            stashes.map { NMapKeyParam(value: $0) },
        ]]
        let keys = try NMapKeyEncodingWorker(
            codingFactory: await polkadotRuntimeService.fetchCoderFactory(),
            path: path,
            storageKeyFactory: StorageKeyFactory(),
            keyParams: params
        ).performEncoding()
        let request = MultipleStorageRequstMock(
            parametersType: .multipleNMap(params: params),
            storagePath: path
        )
        let performer = createPerformer(with: [StorageUpdate(
            blockHash: nil,
            changes: keys.map { [$0.toHex(includePrefix: true), "0x02b55b1200"] }
        )])
        let value = ValidatorPrefs(commission: 77_000_000, blocked: false)
        return (request, performer, Dictionary(uniqueKeysWithValues: stashes.map { ($0, value) }))
    }

    // MARK: - Private methods

    /// Answers like a node: the value under the storage key the request encodes. The cache is
    /// keyed by it, so a response under any other key never reaches it.
    private func createPerformer(
        answering request: StorageRequest,
        with value: String
    ) async throws -> StorageRequestPerformerDefault {
        let codingFactory = try await polkadotRuntimeService.fetchCoderFactory()
        let keys = try StorageRequestKeyEncodingWorkerFactoryDefault().buildFactory(
            storageCodingPath: request.storagePath,
            workerType: request.parametersType.workerType,
            codingFactory: codingFactory,
            storageKeyFactory: StorageKeyFactory()
        ).performEncoding()

        return createPerformer(with: [StorageUpdate(
            blockHash: nil,
            changes: keys.map { [$0.toHex(includePrefix: true), value] }
        )])
    }

    private func createPerformer(with result: [StorageUpdate]) -> StorageRequestPerformerDefault {
        let engine = JSONRPCEngineMock()
        engine.completionResult = result
        return StorageRequestPerformerDefault(chainRegistry: StubChainRegistry(
            runtimeProvider: polkadotRuntimeService,
            connection: engine
        ))
    }

    /// The remote response is saved in the background, so a test that needs the cache waits for it.
    private func fetchUntilCached<T: Decodable & Equatable>(
        _ request: StorageRequest,
        performer: StorageRequestPerformerDefault,
        expected: T
    ) async throws {
        for _ in 0 ..< 50 {
            let _: T? = try await performer.performSingle(request, chain: chain)
            let cached = try await collect(
                await performer.performSingle(request, withCacheOptions: .onCache, chain: chain)
                    as AsyncThrowingStream<CachedStorageResponse<T>, Error>
            )
            if cached.first?.value == expected {
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTFail("The remote value never reached the cache")
    }

    private func collect<T>(
        _ stream: AsyncThrowingStream<CachedStorageResponse<T>, Error>
    ) async throws -> [CachedStorageResponse<T>] {
        var responses: [CachedStorageResponse<T>] = []
        for try await response in stream {
            responses.append(response)
        }
        return responses
    }

    private func account(byte: UInt8) -> AccountId {
        Data(repeating: byte, count: 32)
    }
}

/// Hands the performer one runtime and one connection for every chain.
private final class StubChainRegistry: ChainRegistryProtocol {
    enum StubError: Error {
        case unsupported
    }

    private let runtimeProvider: RuntimeProviderProtocol
    private let connection: JSONRPCEngine

    init(runtimeProvider: RuntimeProviderProtocol, connection: JSONRPCEngine) {
        self.runtimeProvider = runtimeProvider
        self.connection = connection
    }

    func getRuntimeProvider(
        chainId _: ChainModel.Id,
        usedRuntimePaths _: [String: [String]],
        runtimeItem _: RuntimeMetadataItemProtocol?
    ) async throws -> RuntimeProviderProtocol {
        runtimeProvider
    }

    func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? {
        runtimeProvider
    }

    func getSubstrateConnection(for _: ChainModel) throws -> SubstrateConnection {
        connection
    }

    func getEthereumConnection(for _: ChainModel) throws -> Web3EthConnection {
        throw StubError.unsupported
    }

    func getChain(for _: ChainModel.Id) async throws -> ChainModel {
        throw StubError.unsupported
    }

    func getChains() async throws -> [ChainModel] {
        []
    }

    func getReadySnapshot(
        chainId _: ChainModel.Id,
        usedRuntimePaths _: [String: [String]],
        runtimeItem _: RuntimeMetadataItemProtocol?
    ) async throws -> RuntimeSnapshot {
        try await runtimeProvider.readySnapshot()
    }
}

// TODO: - Transfer this model to staking package
struct ValidatorPrefs: Codable, Equatable {
    @StringCodable var commission: BigUInt
    let blocked: Bool
}
