import XCTest
import SSFModels
import RobinHood
import SSFRuntimeCodingService
import BigInt
@testable import fearless

struct CovCPMInfoIntError: Error {}

enum CovCPMInfoIntWrap {
    static func wrapper<T>(_ result: Result<T, Error>) -> CompoundOperationWrapper<T> {
        let operation = BaseOperation<T>()
        operation.result = result
        return CompoundOperationWrapper(targetOperation: operation)
    }
}

final class CovCPMInfoIntOutputSpy: StakingPoolInfoInteractorOutput {
    private(set) var validators: [YourValidatorsModel] = []
    private(set) var palletResults: [Result<Data, Error>] = []
    private(set) var pools: [StakingPool?] = []
    private(set) var errors: [Error] = []
    private(set) var activeEras: [Result<ActiveEraInfo?, Error>] = []
    private(set) var nominations: [Nomination?] = []
    private(set) var eraStakers: [EraStakersInfo] = []

    func didReceiveValidators(validators: YourValidatorsModel) { self.validators.append(validators) }
    func didReceive(palletIdResult: Result<Data, Error>) { palletResults.append(palletIdResult) }
    func didReceive(stakingPool: StakingPool?) { pools.append(stakingPool) }
    func didReceive(error: Error) { errors.append(error) }
    func didReceive(activeEra: Result<ActiveEraInfo?, Error>) { activeEras.append(activeEra) }
    func didReceive(nomination: Nomination?) { nominations.append(nomination) }
    func didReceive(eraStakersInfo: EraStakersInfo) { eraStakers.append(eraStakersInfo) }
}

final class CovCPMInfoIntRuntimeStub: RuntimeCodingServiceProtocol {
    var snapshot: RuntimeSnapshot? { nil }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        let operation = BaseOperation<RuntimeCoderFactoryProtocol>()
        operation.result = .failure(CovCPMInfoIntError())
        return operation
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        throw CovCPMInfoIntError()
    }
}

final class CovCPMInfoIntValidatorFactoryStub: ValidatorOperationFactoryProtocol {
    var nominationResult: Result<Nomination?, Error> = .success(nil)
    var active: [SelectedValidatorInfo] = [SelectedValidatorInfo(address: "active")]
    var pending: [SelectedValidatorInfo] = [SelectedValidatorInfo(address: "pending")]
    var selected: [SelectedValidatorInfo] = [SelectedValidatorInfo(address: "selected")]
    private(set) var calls: [String] = []

    func nomination(accountId _: AccountId) -> CompoundOperationWrapper<Nomination?> {
        calls.append("nomination")
        return CovCPMInfoIntWrap.wrapper(nominationResult)
    }

    func fetchAllValidators() -> CompoundOperationWrapper<[ElectedValidatorInfo]> { CovCPMInfoIntWrap.wrapper(.success([])) }
    func allElectedOperation() -> CompoundOperationWrapper<[ElectedValidatorInfo]> { CovCPMInfoIntWrap.wrapper(.success([])) }

    func allSelectedOperation(by _: Nomination, nominatorAddress _: AccountAddress) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        calls.append("allSelected")
        return CovCPMInfoIntWrap.wrapper(.success(selected))
    }

    func activeValidatorsOperation(for _: AccountAddress) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        calls.append("active")
        return CovCPMInfoIntWrap.wrapper(.success(active))
    }

    func pendingValidatorsOperation(for _: [AccountId]) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        calls.append("pending")
        return CovCPMInfoIntWrap.wrapper(.success(pending))
    }

    func wannabeValidatorsOperation(for _: [AccountId]) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        CovCPMInfoIntWrap.wrapper(.success([]))
    }
}

final class CovCPMInfoIntPoolFactoryStub: StakingPoolOperationFactoryProtocol {
    var bondedPoolResult: Result<StakingPool?, Error> = .success(nil)
    private(set) var requestedPoolIds: [String] = []

    func fetchBondedPoolsOperation() -> CompoundOperationWrapper<[StakingPool]> { CovCPMInfoIntWrap.wrapper(.success([])) }
    func fetchPoolMetadataOperation(poolId _: String) -> CompoundOperationWrapper<String?> { CovCPMInfoIntWrap.wrapper(.success(nil)) }
    func fetchMinJoinBondOperation() -> CompoundOperationWrapper<BigUInt?> { CovCPMInfoIntWrap.wrapper(.success(nil)) }
    func fetchMinCreateBondOperation() -> CompoundOperationWrapper<BigUInt?> { CovCPMInfoIntWrap.wrapper(.success(nil)) }
    func fetchStakingPoolMembers(accountId _: AccountId) -> CompoundOperationWrapper<StakingPoolMember?> {
        CovCPMInfoIntWrap.wrapper(.success(nil))
    }

    func fetchMaxStakingPoolsCount() -> CompoundOperationWrapper<UInt32?> { CovCPMInfoIntWrap.wrapper(.success(nil)) }
    func fetchMaxPoolMembers() -> CompoundOperationWrapper<UInt32?> { CovCPMInfoIntWrap.wrapper(.success(nil)) }
    func fetchCounterForBondedPools() -> CompoundOperationWrapper<UInt32?> { CovCPMInfoIntWrap.wrapper(.success(nil)) }
    func fetchMaxPoolMembersPerPool() -> CompoundOperationWrapper<UInt32?> { CovCPMInfoIntWrap.wrapper(.success(nil)) }

    func fetchBondedPoolOperation(poolId: String) -> CompoundOperationWrapper<StakingPool?> {
        requestedPoolIds.append(poolId)
        return CovCPMInfoIntWrap.wrapper(bondedPoolResult)
    }

    func fetchPoolRewardsOperation(poolId _: String) -> CompoundOperationWrapper<StakingPoolRewards?> {
        CovCPMInfoIntWrap.wrapper(.success(nil))
    }

    func fetchLastPoolId() -> CompoundOperationWrapper<UInt32?> { CovCPMInfoIntWrap.wrapper(.success(nil)) }
    func fetchPendingRewards(accountId _: AccountId) -> CompoundOperationWrapper<BigUInt?> { CovCPMInfoIntWrap.wrapper(.success(nil)) }
}

final class CovCPMInfoIntSubscriptionFactoryStub: RelaychainStakingLocalSubscriptionFactoryProtocol {
    private(set) var activeEraRequests: [ChainModel.Id] = []

    func getMinNominatorBondProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedBigUInt> { throw CovCPMInfoIntError() }
    func getCounterForNominatorsProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> { throw CovCPMInfoIntError() }
    func getMaxNominatorsCountProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> { throw CovCPMInfoIntError() }
    func getNominationProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedNomination> {
        throw CovCPMInfoIntError()
    }

    func getValidatorProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedValidator> {
        throw CovCPMInfoIntError()
    }

    func getLedgerInfoProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedLedgerInfo> {
        throw CovCPMInfoIntError()
    }

    func getActiveEra(for chainId: ChainModel.Id) throws -> AnyDataProvider<DecodedActiveEra> {
        activeEraRequests.append(chainId)
        throw CovCPMInfoIntError()
    }

    func getCurrentEra(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedEraIndex> { throw CovCPMInfoIntError() }
    func getPayee(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedPayee> { throw CovCPMInfoIntError() }

    func getTotalReward(for _: AccountAddress, chain _: ChainModel, assetPrecision _: Int16) throws -> AnySingleValueProvider<TotalRewardItem> {
        throw CovCPMInfoIntError()
    }

    func getStashItemProvider(for address: AccountAddress) -> StreamableProvider<StashItem> {
        SubstrateDataProviderFactory(facade: SubstrateDataStorageFacade.shared, operationManager: OperationManager())
            .createStashItemProvider(for: address)
    }

    func getPoolMembersProvider(for _: ChainAsset, accountId _: AccountId) throws -> AnyDataProvider<DecodedPoolMember> {
        throw CovCPMInfoIntError()
    }
}

final class CovCPMInfoIntEraValidatorServiceStub: EraValidatorServiceProtocol {
    var infoResult: Result<EraStakersInfo, Error> = .success(EraStakersInfo(activeEra: 9, validators: []))

    func setup() {}
    func throttle() {}

    func fetchInfoOperation() -> BaseOperation<EraStakersInfo> {
        let operation = BaseOperation<EraStakersInfo>()
        operation.result = infoResult
        return operation
    }
}

final class CovCPMPoolInfoInteractorTests: XCTestCase {
    private var chainAsset: ChainAsset!
    private var validatorFactory: CovCPMInfoIntValidatorFactoryStub!
    private var poolFactory: CovCPMInfoIntPoolFactoryStub!
    private var subscriptionFactory: CovCPMInfoIntSubscriptionFactoryStub!
    private var eraService: CovCPMInfoIntEraValidatorServiceStub!
    private var output: CovCPMInfoIntOutputSpy!

    override func setUp() {
        super.setUp()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        chainAsset = ChainAsset(chain: chain, asset: asset)
        validatorFactory = CovCPMInfoIntValidatorFactoryStub()
        poolFactory = CovCPMInfoIntPoolFactoryStub()
        subscriptionFactory = CovCPMInfoIntSubscriptionFactoryStub()
        eraService = CovCPMInfoIntEraValidatorServiceStub()
        output = CovCPMInfoIntOutputSpy()
    }

    override func tearDown() {
        chainAsset = nil
        validatorFactory = nil
        poolFactory = nil
        subscriptionFactory = nil
        eraService = nil
        output = nil
        super.tearDown()
    }

    private func makeInteractor() -> StakingPoolInfoInteractor {
        StakingPoolInfoInteractor(
            chainAsset: chainAsset,
            operationManager: OperationManager(),
            runtimeService: CovCPMInfoIntRuntimeStub(),
            validatorOperationFactory: validatorFactory,
            poolId: "12",
            stakingPoolOperationFactory: poolFactory,
            stakingLocalSubscriptionFactory: subscriptionFactory,
            eraValidatorService: eraService
        )
    }

    private func spin(until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    private func nomination(submittedIn: UInt32) throws -> Nomination {
        let json: [String: Any] = ["targets": [Data(repeating: 3, count: 32).base64EncodedString()], "submittedIn": "\(submittedIn)"]
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(Nomination.self, from: data)
    }

    func testSetupDeliversPalletPoolAndEraStakers() {
        let pool = StakingPool(
            id: "12",
            info: StakingPoolInfo(points: 1, state: .open, memberCounter: 1, roles: StakingPoolRoles(depositor: Data(repeating: 1, count: 32))),
            name: "Twelve"
        )
        poolFactory.bondedPoolResult = .success(pool)
        let interactor = makeInteractor()

        interactor.setup(with: output)
        spin { !output.palletResults.isEmpty && !output.pools.isEmpty && !output.eraStakers.isEmpty }

        XCTAssertEqual(poolFactory.requestedPoolIds, ["12"])
        XCTAssertEqual(subscriptionFactory.activeEraRequests, [chainAsset.chain.chainId])
        guard case .failure? = output.palletResults.first else {
            return XCTFail("expected pallet id failure from stub runtime")
        }
        XCTAssertEqual(output.pools.first??.name, "Twelve")
        XCTAssertEqual(output.eraStakers.first?.activeEra, 9)
        XCTAssertTrue(output.errors.isEmpty)
    }

    func testSetupReportsPoolAndEraStakersErrors() {
        poolFactory.bondedPoolResult = .failure(CovCPMInfoIntError())
        eraService.infoResult = .failure(CovCPMInfoIntError())
        let interactor = makeInteractor()

        interactor.setup(with: output)
        spin { output.errors.count >= 2 && !output.palletResults.isEmpty }

        XCTAssertEqual(output.errors.count, 2)
        XCTAssertTrue(output.pools.isEmpty)
        XCTAssertTrue(output.eraStakers.isEmpty)
    }

    func testMissingNominationDeliversEmptyValidators() {
        let interactor = makeInteractor()
        interactor.setup(with: output)

        interactor.fetchPoolNomination(poolStashAccountId: Data(repeating: 5, count: 32), activeEra: 4)
        spin { !output.validators.isEmpty }

        XCTAssertEqual(output.nominations.count, 1)
        XCTAssertNil(output.nominations.first ?? nil)
        XCTAssertEqual(output.validators.first?.allValidators.count, 0)
        XCTAssertEqual(validatorFactory.calls, ["nomination"])
    }

    func testRecentNominationUsesActiveAndPendingValidators() throws {
        validatorFactory.nominationResult = .success(try nomination(submittedIn: 10))
        let interactor = makeInteractor()
        interactor.setup(with: output)

        interactor.fetchPoolNomination(poolStashAccountId: Data(repeating: 5, count: 32), activeEra: 4)
        spin { !output.validators.isEmpty }

        XCTAssertEqual(validatorFactory.calls, ["nomination", "active", "pending"])
        XCTAssertEqual(output.validators.first?.currentValidators.map(\.address), ["active"])
        XCTAssertEqual(output.validators.first?.pendingValidators.map(\.address), ["pending"])
        XCTAssertEqual(output.nominations.first??.submittedIn, 10)
    }

    func testOlderNominationUsesSelectedValidators() throws {
        validatorFactory.nominationResult = .success(try nomination(submittedIn: 1))
        let interactor = makeInteractor()
        interactor.setup(with: output)

        interactor.fetchPoolNomination(poolStashAccountId: Data(repeating: 5, count: 32), activeEra: 4)
        spin { !output.validators.isEmpty }

        XCTAssertEqual(validatorFactory.calls, ["nomination", "allSelected"])
        XCTAssertEqual(output.validators.first?.currentValidators.map(\.address), ["selected"])
        XCTAssertEqual(output.validators.first?.pendingValidators.count, 0)
    }

    func testNominationFailureIsReported() {
        validatorFactory.nominationResult = .failure(CovCPMInfoIntError())
        poolFactory.bondedPoolResult = .success(nil)
        let interactor = makeInteractor()
        interactor.setup(with: output)
        spin { !output.pools.isEmpty && !output.eraStakers.isEmpty }

        interactor.fetchPoolNomination(poolStashAccountId: Data(repeating: 5, count: 32), activeEra: 4)
        spin { !output.errors.isEmpty }

        XCTAssertEqual(output.errors.count, 1)
        XCTAssertTrue(output.validators.isEmpty)
    }

    func testActiveEraHandlerForwardsResult() {
        let interactor = makeInteractor()
        interactor.setup(with: output)

        interactor.handleActiveEra(result: .success(ActiveEraInfo(index: 33)), chainId: chainAsset.chain.chainId)

        guard case let .success(info)? = output.activeEras.last else {
            return XCTFail("expected active era")
        }
        XCTAssertEqual(info?.index, 33)
    }
}
