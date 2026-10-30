import XCTest
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import SSFUtils
@testable import fearless

final class AssetHubRewardServiceTests: XCTestCase {
    func testServiceUsesPriorEraObservedRewardAndRejectsRequestBeforeSetup() throws {
        let fixture = try Fixture()
        XCTAssertThrowsError(try fixture.execute(fixture.service.fetchCalculatorOperation()))
        fixture.service.setup()
        let engine = try fixture.execute(fixture.service.fetchCalculatorOperation())
        let value = try engine.calculateEarnings(amount: 100, validatorAccountId: AssetHubTestSupport.first, isCompound: false, period: .day)
        XCTAssertEqual(NSDecimalNumber(decimal: value).doubleValue, 17.7777777777778, accuracy: 0.000000001)
        XCTAssertEqual(fixture.era.setups, 1)
        XCTAssertEqual(Set(fixture.storage.requestedPaths.map(\.itemName)), Set([fearless.StorageCodingPath.totalValidatorReward.itemName, fearless.StorageCodingPath.rewardPointsPerValidator.itemName]))
        XCTAssertEqual(fixture.storage.stringParameters[fearless.StorageCodingPath.totalValidatorReward.itemName], ["8"], "The last completed era is read")
    }

    func testServicePreservesDependencyFailureAndDoesNotInventMissingReward() throws {
        let fixture = try Fixture()
        fixture.service.setup()
        let failure = NSError(domain: "asset-hub-reward", code: 42)
        fixture.era.failure = failure
        XCTAssertThrowsError(try fixture.execute(fixture.service.fetchCalculatorOperation())) { XCTAssertEqual($0 as NSError, failure) }
        fixture.era.failure = nil
        fixture.storage.entries.removeValue(forKey: fearless.StorageCodingPath.totalValidatorReward.itemName)
        XCTAssertThrowsError(try fixture.execute(fixture.service.fetchCalculatorOperation()))
    }

    func testThrottleInvalidatesAlreadyCreatedOperationAndSetupStartsFreshGeneration() throws {
        let fixture = try Fixture()
        fixture.service.setup()
        fixture.manager.queue.isSuspended = true
        let stale = fixture.service.fetchCalculatorOperation()
        fixture.service.throttle()
        fixture.service.setup()
        fixture.manager.queue.isSuspended = false
        XCTAssertThrowsError(try fixture.execute(stale))
        XCTAssertNoThrow(try fixture.execute(fixture.service.fetchCalculatorOperation()))
    }

    func testUnavailableRuntimeOrConnectionCannotProduceAnEstimate() throws {
        let fixture = try Fixture()
        fixture.service.setup()
        fixture.registry.hasRuntime = false
        XCTAssertThrowsError(try fixture.execute(fixture.service.fetchCalculatorOperation()))
        fixture.registry.hasRuntime = true
        fixture.registry.hasConnection = false
        XCTAssertThrowsError(try fixture.execute(fixture.service.fetchCalculatorOperation()))
    }

    func testChainOutsideTheRoutesIsRefused() throws {
        let fixture = try Fixture(chainId: "legacy")
        fixture.service.setup()
        XCTAssertThrowsError(try fixture.execute(fixture.service.fetchCalculatorOperation()))
        XCTAssertTrue(fixture.storage.requestedPaths.isEmpty)
    }

    private final class Fixture {
        let registry = Registry()
        let storage = RecordingStorage()
        let era = EraService()
        let manager = Manager()
        let service: AssetHubRewardCalculatorService

        init(chainId: String? = nil) throws {
            let runtime = try AssetHubRuntimeFixture(name: "polkadot")
            registry.runtime = runtime
            era.validators = try [
                AssetHubTestSupport.validator(AssetHubTestSupport.first),
                AssetHubTestSupport.validator(AssetHubTestSupport.second)
            ]
            manager.queue.maxConcurrentOperationCount = 1
            try storage.put(.totalValidatorReward, value: "100")
            try storage.put(.rewardPointsPerValidator, value: [
                "total": "3",
                "individual": [
                    [AssetHubTestSupport.first.base64EncodedString(), "2"],
                    [AssetHubTestSupport.second.base64EncodedString(), "1"]
                ]
            ])
            service = AssetHubRewardCalculatorService(
                chainId: chainId ?? runtime.chainId, registry: registry, validators: era,
                storage: storage, manager: manager, duration: Duration()
            )
        }

        func execute<Value>(_ operation: BaseOperation<Value>) throws -> Value {
            let done = XCTestExpectation(description: "reward operation")
            operation.completionBlock = { done.fulfill() }
            manager.enqueue(operations: [operation], in: .transient)
            guard XCTWaiter.wait(for: [done], timeout: 5) == .completed else {
                throw NSError(domain: "reward operation timed out", code: 1)
            }
            return try XCTUnwrap(operation.result).get()
        }
    }

    private final class Registry: ChainRegistryProtocolStub, @unchecked Sendable {
        var hasConnection = true
        var hasRuntime = true
        var runtime: RuntimeProviderProtocol?

        override func getConnection(for _: ChainModel.Id) -> ChainConnection? {
            hasConnection ? MockConnection() : nil
        }

        override func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? {
            hasRuntime ? runtime : nil
        }
    }

    private final class EraService: EraValidatorServiceProtocol {
        var validators: [EraValidatorInfo] = []
        var failure: Error?
        private(set) var setups = 0
        func setup() { setups += 1 }
        func throttle() {}
        func fetchInfoOperation() -> BaseOperation<EraStakersInfo> {
            ClosureOperation {
                if let failure = self.failure { throw failure }
                return EraStakersInfo(activeEra: 9, validators: self.validators)
            }
        }
    }

    private struct Duration: StakingDurationOperationFactoryProtocol {
        func createDurationOperation(from _: RuntimeCodingServiceProtocol) -> CompoundOperationWrapper<StakingDuration> {
            CompoundOperationWrapper(targetOperation: ClosureOperation {
                StakingDuration(session: 14400, era: 86400, unlocking: 2_419_200)
            })
        }
    }

    private final class Manager: OperationManagerProtocol {
        let queue = OperationQueue()
        private lazy var underlying = OperationManager(operationQueue: queue)
        func enqueue(operations: [Operation], in mode: OperationMode) {
            underlying.enqueue(operations: operations, in: mode)
        }
    }

    /// Answers storage reads from JSON values, recording what was asked.
    private final class RecordingStorage: StorageRequestFactoryProtocol {
        struct Entry {
            let key: Data
            let json: Data?
        }

        var entries: [String: [Entry]] = [:]
        private(set) var stringParameters: [String: [String]] = [:]
        private(set) var requestedPaths: [fearless.StorageCodingPath] = []

        func put(_ path: fearless.StorageCodingPath, key: Data = Data(), value: Any?) throws {
            let json = try value.map { try JSONSerialization.data(withJSONObject: $0, options: .fragmentsAllowed) }
            entries[path.itemName, default: []].append(Entry(key: key, json: json))
        }

        private func query<T: Decodable>(
            path: fearless.StorageCodingPath,
            factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
            prepare: @escaping () throws -> Void
        ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
            CompoundOperationWrapper(targetOperation: ClosureOperation {
                _ = try factory()
                try prepare()
                self.requestedPaths.append(path)
                return try self.entries[path.itemName, default: []].map { entry in
                    let value = try entry.json.map { try JSONDecoder().decode(T.self, from: $0) }
                    return StorageResponse(key: entry.key, data: entry.json, value: value)
                }
            })
        }

        func queryItems<K: Encodable, T: Decodable>(
            engine _: JSONRPCEngine, keyParams: @escaping () throws -> [K],
            factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
            storagePath: fearless.StorageCodingPath, at _: Data?
        ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
            query(path: storagePath, factory: factory) {
                let params = try keyParams()
                if let mapped = params as? [fearless.StringScaleMapper<UInt32>] {
                    self.stringParameters[storagePath.itemName] = mapped.map { String($0.value) }
                }
            }
        }

        func queryItems<T: Decodable>(
            engine _: JSONRPCEngine, keys _: @escaping () throws -> [Data],
            factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
            storagePath: fearless.StorageCodingPath, at _: Data?
        ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
            query(path: storagePath, factory: factory) {}
        }

        func queryItems<T: Decodable>(
            engine _: JSONRPCEngine, keyParams _: @escaping () throws -> [[NMapKeyParamProtocol]],
            factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
            storagePath: fearless.StorageCodingPath, at _: Data?
        ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
            query(path: storagePath, factory: factory) {}
        }

        // swiftlint:disable:next function_parameter_count
        func queryItems<K1: Encodable, K2: Encodable, T: Decodable>(
            engine _: JSONRPCEngine, keyParams1 _: @escaping () throws -> [K1],
            keyParams2 _: @escaping () throws -> [K2], factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
            storagePath _: fearless.StorageCodingPath, at _: Data?
        ) -> CompoundOperationWrapper<[StorageResponse<T>]> { .createWithError(unsupported()) }

        // swiftlint:disable:next function_parameter_count
        func queryChildItem<T: Decodable>(
            engine _: JSONRPCEngine, storageKeyParam _: @escaping () throws -> Data,
            childKeyParam _: @escaping () throws -> Data, factory _: @escaping () throws -> RuntimeCoderFactoryProtocol,
            mapper _: DynamicScaleDecodable, at _: Data?
        ) -> CompoundOperationWrapper<ChildStorageResponse<T>> { .createWithError(unsupported()) }

        func queryItemsByPrefix<T: Decodable>(
            engine _: JSONRPCEngine, keys _: @escaping () throws -> [Data],
            factory: @escaping () throws -> RuntimeCoderFactoryProtocol,
            storagePath: fearless.StorageCodingPath, at _: Data?
        ) -> CompoundOperationWrapper<[StorageResponse<T>]> {
            query(path: storagePath, factory: factory) {}
        }

        private func unsupported() -> NSError { NSError(domain: "unexpected storage request", code: 1) }
    }
}
