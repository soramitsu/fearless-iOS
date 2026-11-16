import XCTest
import BigInt
import RobinHood
import SSFModels
import SSFUtils
import SSFRuntimeCodingService
@testable import fearless

struct CovBRsDuration: StakingDurationOperationFactoryProtocol {
    var era: TimeInterval = 21600

    func createDurationOperation(from _: RuntimeCodingServiceProtocol) -> CompoundOperationWrapper<StakingDuration> {
        let era = era
        return CompoundOperationWrapper(targetOperation: ClosureOperation {
            StakingDuration(session: era / 6, era: era, unlocking: era * 28)
        })
    }
}

enum CovBRsSupport {
    /// Asks for the calculator until one request is answered; a request made before the service has its data waits.
    static func engine(
        of service: RewardCalculatorServiceProtocol,
        manager: OperationManagerProtocol,
        attempts: Int = 30
    ) throws -> RewardCalculatorEngineProtocol {
        for _ in 0 ..< attempts {
            let operation = service.fetchCalculatorOperation()
            let done = XCTestExpectation(description: "calculator")
            operation.completionBlock = { done.fulfill() }
            manager.enqueue(operations: [operation], in: .transient)
            if XCTWaiter.wait(for: [done], timeout: 1) == .completed {
                return try XCTUnwrap(operation.result).get()
            }
        }
        throw CovBSkError(code: 408)
    }

    static func chainAsset(_ chain: ChainModel) throws -> ChainAsset {
        ChainAsset(chain: chain, asset: try XCTUnwrap(chain.assets.first))
    }
}

final class CovBRsInflationServiceTests: XCTestCase {
    typealias Fx = CovBSkFixtures

    func testStoredTotalIssuanceBuildsAnInflationEngine() throws {
        let facade = SubstrateStorageTestFacade()
        let manager = OperationManager()
        let source = try AssetHubStorageFixture()
        let chain = Fx.chain(precision: 0)
        let registry = CovBSkRegistry()
        registry.register(chain.chainId, connection: MockConnection(), runtime: source.runtime)
        let era = CovBSkEraService()
        era.info = EraStakersInfo(activeEra: 1, validators: try CovBReFixtures.validators())

        let key = try LocalStorageKeyFactory().createFromStoragePath(.totalIssuance, chainId: chain.chainId)
        var issuance = Data(repeating: 0, count: 16)
        issuance[0] = 100
        let repository: CoreDataRepository<ChainStorageItem, fearless.CDChainStorageItem> = facade.createRepository()
        let save = repository.saveOperation({ [ChainStorageItem(identifier: key, data: issuance)] }, { [] })
        OperationQueue().addOperations([save], waitUntilFinished: true)
        _ = try XCTUnwrap(save.result).get()

        let service = InflationRewardCalculatorService(
            chainAsset: try CovBRsSupport.chainAsset(chain),
            assetPrecision: 0,
            eraValidatorsService: era,
            operationManager: manager,
            providerFactory: SubstrateDataProviderFactory(facade: facade, operationManager: manager),
            chainRegistry: registry,
            stakingDurationFactory: CovBRsDuration(),
            storageFacade: facade
        )
        // Throttling a service that was never set up leaves it able to start.
        service.throttle()
        service.setup()
        service.setup()

        let engine = try CovBRsSupport.engine(of: service, manager: manager)

        XCTAssertTrue(engine is RewardCalculatorEngine)
        // Total issuance 100 with 60 staked gives the 0.085 inflation of the engine tests.
        covBReAssertClose(try engine.calculateEarnings(amount: 100, validatorAccountId: Fx.validatorA, isCompound: false, period: .year), 8.5)
        XCTAssertEqual(era.setups, 2)

        let second = try CovBRsSupport.engine(of: service, manager: manager, attempts: 1)
        covBReAssertClose(second.calculateMaxEarnings(amount: 1, isCompound: false, period: .year), 0.085 * 20 / 6)
        service.throttle()
    }
}

final class CovBRsPortionServiceTests: XCTestCase {
    typealias Fx = CovBSkFixtures

    func testAverageValidatorRewardBuildsAPortionEngine() throws {
        let facade = SubstrateStorageTestFacade()
        let manager = OperationManager()
        let chain = Fx.chain(id: "covb-para", precision: 0)
        let registry = CovBSkRegistry()
        registry.register(chain.chainId, connection: MockConnection(), runtime: CovBSkRuntimeProvider(try StakingConstantRuntime()))
        let era = CovBSkEraService()
        era.info = EraStakersInfo(activeEra: 1, validators: try CovBReFixtures.validators())
        let storage = CovBSkStorage()
        storage.putPrefixed(.totalValidatorReward, key: Data([1]), json: "100")
        storage.putPrefixed(.totalValidatorReward, key: Data([2]), json: "300")

        let service = PortionRewardCalculatorService(
            chainAsset: try CovBRsSupport.chainAsset(chain),
            assetPrecision: 0,
            eraValidatorsService: era,
            operationManager: manager,
            providerFactory: SubstrateDataProviderFactory(facade: facade, operationManager: manager),
            chainRegistry: registry,
            stakingDurationFactory: CovBRsDuration(),
            storageFacade: facade,
            storageRequestFactory: storage
        )
        service.throttle()
        service.setup()

        let engine = try CovBRsSupport.engine(of: service, manager: manager)

        XCTAssertTrue(engine is PortionRewardCalculatorEngine)
        // An average of 200 per era shared by three validators; A keeps 90 % of 200 / 3 over its 30 staked, four eras a day.
        covBReAssertClose(try engine.calculateEarnings(amount: 1, validatorAccountId: Fx.validatorA, isCompound: false, period: .day), 8)
        XCTAssertEqual(storage.requests(.totalValidatorReward), [[try StorageKeyFactory().key(from: .totalValidatorReward).toHex()]])
        XCTAssertEqual(era.setups, 1)
        service.throttle()
    }
}
