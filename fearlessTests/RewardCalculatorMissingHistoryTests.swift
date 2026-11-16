import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
import XCTest
@testable import fearless

/// A chain without reward history must give the staking screens an error, not crash the app.
final class RewardCalculatorMissingHistoryTests: XCTestCase {
    /// The portion calculator averaged the total validator rewards by dividing by their count, which trapped when the
    /// chain returned none. Waiting requests now get an error, and so do later ones.
    func testPortionServiceReportsMissingRewardHistory() throws {
        let manager = OperationManager()
        let facade = SubstrateStorageTestFacade()
        let registry = SoraRewardServiceRegistry()
        registry.runtime = try SoraRewardServiceRegistry.sharedRuntime()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("ksm", symbol: "KSM", assetPresicion: 12)
        let service = PortionRewardCalculatorService(
            chainAsset: ChainAsset(chain: chain, asset: asset),
            assetPrecision: 12,
            eraValidatorsService: SoraRewardServiceEraStub(),
            operationManager: manager,
            providerFactory: SubstrateDataProviderFactory(facade: facade, operationManager: manager),
            chainRegistry: registry,
            stakingDurationFactory: SoraRewardServiceDuration(),
            storageFacade: facade,
            storageRequestFactory: EmptyStorageRequestFactory()
        )

        let waiting = service.fetchCalculatorOperation()
        let waitingDone = XCTestExpectation(description: "the waiting request completes")
        waiting.completionBlock = { waitingDone.fulfill() }
        manager.enqueue(operations: [waiting], in: .transient)
        service.setup()

        XCTAssertEqual(XCTWaiter.wait(for: [waitingDone], timeout: 30), .completed)
        assertMissingHistory(waiting.result)

        let later = service.fetchCalculatorOperation()
        let laterDone = XCTestExpectation(description: "a later request completes")
        later.completionBlock = { laterDone.fulfill() }
        manager.enqueue(operations: [later], in: .transient)
        XCTAssertEqual(XCTWaiter.wait(for: [laterDone], timeout: 10), .completed)
        assertMissingHistory(later.result)
    }

    /// The SORA engine dropped the running era with `prefix(count - 1)`, which traps on an empty history.
    func testSoraEngineReportsMissingRewardHistory() throws {
        let fixture = try SoraRewardServiceFixture(dexCount: 1)
        let engine = SoraRewardCalculatorEngine(
            totalStakeByEra: [:],
            rewardPointsByEra: [:],
            validatorRewardsByEra: [:],
            validators: fixture.eraService.info.validators,
            chainAsset: fixture.stakingAsset,
            eraDurationInSeconds: 21600
        )

        XCTAssertThrowsError(
            try engine.calculateEarnings(
                amount: 1, validatorAccountId: SoraRewardServiceFixture.validatorA, isCompound: false, period: .year
            )
        ) { error in
            guard case RewardCalculatorEngineError.missingRewardHistory = error else {
                return XCTFail("unexpected \(error)")
            }
        }
        XCTAssertEqual(engine.calculatorReturn(isCompound: false, period: .year, type: .avg), 0)
        XCTAssertEqual(engine.calculatorReturn(isCompound: false, period: .year, type: .max(nil)), 0)
    }

    private func assertMissingHistory(
        _ result: Result<RewardCalculatorEngineProtocol, Error>?,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case let .failure(error) = result else {
            return XCTFail("expected an error, got \(String(describing: result))", file: file, line: line)
        }
        guard case RewardCalculatorEngineError.missingRewardHistory = error else {
            return XCTFail("unexpected \(error)", file: file, line: line)
        }
    }
}

/// Answers every storage query with no entries.
final class EmptyStorageRequestFactory: StorageRequestFactoryProtocol {
    private func empty<T>() -> CompoundOperationWrapper<[StorageResponse<T>]> {
        CompoundOperationWrapper(targetOperation: ClosureOperation { [] })
    }

    func queryItems<K: Encodable, T: Decodable>(
        engine _: JSONRPCEngine, keyParams _: @escaping () throws -> [K],
        factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath _: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> { empty() }

    // swiftlint:disable:next function_parameter_count
    func queryItems<K1: Encodable, K2: Encodable, T: Decodable>(
        engine _: JSONRPCEngine, keyParams1 _: @escaping () throws -> [K1],
        keyParams2 _: @escaping () throws -> [K2], factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath _: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> { empty() }

    func queryItems<T: Decodable>(
        engine _: JSONRPCEngine, keys _: @escaping () throws -> [Data],
        factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath _: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> { empty() }

    // swiftlint:disable:next function_parameter_count
    func queryChildItem<T: Decodable>(
        engine _: JSONRPCEngine, storageKeyParam _: @escaping () throws -> Data,
        childKeyParam _: @escaping () throws -> Data, factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        mapper _: DynamicScaleDecodable, at _: Data?
    ) -> CompoundOperationWrapper<ChildStorageResponse<T>> {
        .createWithError(NSError(domain: "empty-storage", code: 1))
    }

    func queryItems<T: Decodable>(
        engine _: JSONRPCEngine, keyParams _: @escaping () throws -> [[NMapKeyParamProtocol]],
        factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath _: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> { empty() }

    func queryItemsByPrefix<T: Decodable>(
        engine _: JSONRPCEngine, keys _: @escaping () throws -> [Data],
        factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
        storagePath _: fearless.StorageCodingPath, at _: Data?
    ) -> CompoundOperationWrapper<[StorageResponse<T>]> { empty() }
}
