import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

/// A reward calculator that cannot build an engine must tell the staking screens. The services only logged their
/// errors, and dropped a request when the runtime was missing, so the waiting request never finished.
final class RewardCalculatorFailureDeliveryTests: XCTestCase {
    func testInflationServiceReportsAMissingRuntimeToTheWaitingRequest() throws {
        let manager = OperationManager()
        let facade = SubstrateStorageTestFacade()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        let key = try LocalStorageKeyFactory().createFromStoragePath(.totalIssuance, chainId: chain.chainId)
        let repository: CoreDataRepository<ChainStorageItem, fearless.CDChainStorageItem> = facade.createRepository()
        let save = repository.saveOperation({ [ChainStorageItem(identifier: key, data: Data(repeating: 1, count: 16))] }, { [] })
        OperationQueue().addOperations([save], waitUntilFinished: true)
        let service = InflationRewardCalculatorService(
            chainAsset: ChainAsset(chain: chain, asset: asset),
            assetPrecision: 10,
            eraValidatorsService: SoraRewardServiceEraStub(),
            operationManager: manager,
            providerFactory: SubstrateDataProviderFactory(facade: facade, operationManager: manager),
            chainRegistry: SoraRewardServiceRegistry(),
            stakingDurationFactory: SoraRewardServiceDuration(),
            storageFacade: facade
        )

        let result = try request(from: service, manager: manager) { service.setup() }

        assertError(result, ChainRegistryError.runtimeMetadaUnavailable)
    }

    func testPortionServiceReportsAMissingRuntimeToWaitingAndLaterRequests() throws {
        let manager = OperationManager()
        let facade = SubstrateStorageTestFacade()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("ksm", symbol: "KSM", assetPresicion: 12)
        let service = PortionRewardCalculatorService(
            chainAsset: ChainAsset(chain: chain, asset: asset),
            assetPrecision: 12,
            eraValidatorsService: SoraRewardServiceEraStub(),
            operationManager: manager,
            providerFactory: SubstrateDataProviderFactory(facade: facade, operationManager: manager),
            chainRegistry: SoraRewardServiceRegistry(),
            stakingDurationFactory: SoraRewardServiceDuration(),
            storageFacade: facade,
            storageRequestFactory: EmptyStorageRequestFactory()
        )

        let waiting = try request(from: service, manager: manager) { service.setup() }
        let later = try request(from: service, manager: manager) {}

        assertError(waiting, ChainRegistryError.runtimeMetadaUnavailable)
        assertError(later, ChainRegistryError.runtimeMetadaUnavailable)
    }

    func testPortionServiceReportsAnEngineThatCannotBeBuilt() throws {
        let manager = OperationManager()
        let facade = SubstrateStorageTestFacade()
        let registry = SoraRewardServiceRegistry()
        registry.runtime = try SoraRewardServiceRegistry.sharedRuntime()
        let storage = WannabeValidatorPrefsStorage(prefs: [:])
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("ksm", symbol: "KSM", assetPresicion: 12)
        let eraService = SoraRewardServiceEraStub()
        eraService.failure = NSError(domain: "era-stakers", code: 15)
        let service = PortionRewardCalculatorService(
            chainAsset: ChainAsset(chain: chain, asset: asset),
            assetPrecision: 12,
            eraValidatorsService: eraService,
            operationManager: manager,
            providerFactory: SubstrateDataProviderFactory(facade: facade, operationManager: manager),
            chainRegistry: registry,
            stakingDurationFactory: SoraRewardServiceDuration(),
            storageFacade: facade,
            storageRequestFactory: OneRewardStorageRequestFactory(base: storage)
        )

        let result = try request(from: service, manager: manager) { service.setup() }

        assertError(result, NSError(domain: "era-stakers", code: 15))
    }

    func testSoraServiceReportsAnUnreadableRewardHistory() throws {
        let fixture = try SoraRewardServiceFixture(dexCount: 1)
        fixture.performer.failure = NSError(domain: "reward-history", code: 15)

        let result = try request(from: fixture.service, manager: fixture.manager) { fixture.service.setup() }

        assertError(result, NSError(domain: "reward-history", code: 15))
    }

    // MARK: - Private

    private func request(
        from service: RewardCalculatorServiceProtocol,
        manager: OperationManagerProtocol,
        after action: () -> Void
    ) throws -> Result<RewardCalculatorEngineProtocol, Error> {
        let operation = service.fetchCalculatorOperation()
        let done = XCTestExpectation(description: "the request completes")
        operation.completionBlock = { done.fulfill() }
        manager.enqueue(operations: [operation], in: .transient)
        action()
        XCTAssertEqual(XCTWaiter.wait(for: [done], timeout: 10), .completed, "the request finishes")
        return try XCTUnwrap(operation.result)
    }

    private func assertError(
        _ result: Result<RewardCalculatorEngineProtocol, Error>,
        _ expected: Error,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .failure(error) = result else {
            return XCTFail("expected \(expected), got an engine", file: file, line: line)
        }
        XCTAssertEqual(
            String(describing: error), String(describing: expected), file: file, line: line
        )
    }
}

/// Answers the total validator reward prefix read with one era of rewards.
final class OneRewardStorageRequestFactory: StorageRequestFactoryProtocol {
    let base: StorageRequestFactoryProtocol

    init(base: StorageRequestFactoryProtocol) {
        self.base = base
    }

    func queryItems<K: Encodable, T: Decodable>(
        engine: JSONRPCEngine, keyParams: @escaping () throws -> [K],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath, at blockHash: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        base.queryItems(engine: engine, keyParams: keyParams, factory: factory, storagePath: storagePath, at: blockHash)
    }

    // swiftlint:disable:next function_parameter_count
    func queryItems<K1: Encodable, K2: Encodable, T: Decodable>(
        engine: JSONRPCEngine, keyParams1: @escaping () throws -> [K1],
        keyParams2: @escaping () throws -> [K2], factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath, at blockHash: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        base.queryItems(
            engine: engine, keyParams1: keyParams1, keyParams2: keyParams2, factory: factory,
            storagePath: storagePath, at: blockHash
        )
    }

    func queryItems<T: Decodable>(
        engine: JSONRPCEngine, keys: @escaping () throws -> [Data],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath, at blockHash: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        base.queryItems(engine: engine, keys: keys, factory: factory, storagePath: storagePath, at: blockHash)
    }

    // swiftlint:disable:next function_parameter_count
    func queryChildItem<T: Decodable>(
        engine: JSONRPCEngine, storageKeyParam: @escaping () throws -> Data,
        childKeyParam: @escaping () throws -> Data, factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        mapper: DynamicScaleDecodable, at blockHash: Data?
    ) -> CompoundOperationWrapper<ChildStorageResponse<T>> {
        base.queryChildItem(
            engine: engine, storageKeyParam: storageKeyParam, childKeyParam: childKeyParam, factory: factory,
            mapper: mapper, at: blockHash
        )
    }

    func queryItems<T: Decodable>(
        engine: JSONRPCEngine, keyParams: @escaping () throws -> [[NMapKeyParamProtocol]],
        factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath: fearless.StorageCodingPath, at blockHash: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        base.queryItems(engine: engine, keyParams: keyParams, factory: factory, storagePath: storagePath, at: blockHash)
    }

    func queryItemsByPrefix<T: Decodable>(
        engine _: JSONRPCEngine, keys _: @escaping () throws -> [Data],
        factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath _: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
        CompoundOperationWrapper(targetOperation: ClosureOperation {
            let data = try JSONSerialization.data(withJSONObject: "1000000", options: .fragmentsAllowed)
            return [StorageResponse(key: Data([1]), data: data, value: try JSONDecoder().decode(T.self, from: data))]
        })
    }
}
