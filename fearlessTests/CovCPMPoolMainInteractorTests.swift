import XCTest
import SSFModels
import RobinHood
import SSFRuntimeCodingService
import SoraKeystore
import BigInt
import Web3
@testable import fearless

struct CovCPMMainIntError: Error {}

enum CovCPMMainIntWrap {
    static func wrapper<T>(_ result: Result<T, Error>) -> CompoundOperationWrapper<T> {
        let operation = BaseOperation<T>()
        operation.result = result
        return CompoundOperationWrapper(targetOperation: operation)
    }
}

final class CovCPMMainIntOutputSpy: StakingPoolMainInteractorOutput {
    private let lock = NSLock()
    private var engineCallsStorage = 0
    private(set) var accountInfos: [AccountInfo?] = []
    private(set) var chainAssets: [ChainAsset] = []
    private(set) var wallets: [fearless.MetaAccountModel] = []
    private(set) var networkInfos: [StakingPoolNetworkInfo] = []
    private(set) var stakeInfos: [StakingPoolMember?] = []
    private(set) var eras: [EraIndex?] = []
    private(set) var eraStakers: [EraStakersInfo] = []
    private(set) var countdownResults: [Result<EraCountdown, Error>] = []
    private(set) var poolRewards: [StakingPoolRewards?] = []
    private(set) var pools: [StakingPool?] = []
    private(set) var palletResults: [Result<Data, Error>] = []
    private(set) var poolAccountInfos: [AccountInfo?] = []
    private(set) var existentialDeposits: [Result<BigUInt, Error>] = []
    private(set) var nominations: [Nomination?] = []
    private(set) var errors: [StakingPoolMainError] = []
    private(set) var pendingRewards: [BigUInt?] = []
    private(set) var pendingRewardsErrors: [Error] = []

    var engineCalls: Int {
        lock.lock()
        defer { lock.unlock() }
        return engineCallsStorage
    }

    func didReceive(rewardCalculatorEngine _: RewardCalculatorEngineProtocol?) {
        lock.lock()
        engineCallsStorage += 1
        lock.unlock()
    }

    func didReceive(accountInfo: AccountInfo?) { accountInfos.append(accountInfo) }
    func didReceive(chainAsset: ChainAsset) { chainAssets.append(chainAsset) }
    func didReceive(wallet: fearless.MetaAccountModel) { wallets.append(wallet) }
    func didReceive(networkInfo: StakingPoolNetworkInfo) { networkInfos.append(networkInfo) }
    func didReceive(stakeInfo: StakingPoolMember?) { stakeInfos.append(stakeInfo) }
    func didReceive(era: EraIndex?) { eras.append(era) }
    func didReceive(eraStakersInfo: EraStakersInfo) { eraStakers.append(eraStakersInfo) }
    func didReceive(eraCountdownResult: Result<EraCountdown, Error>) { countdownResults.append(eraCountdownResult) }
    func didReceive(poolRewards: StakingPoolRewards?) { self.poolRewards.append(poolRewards) }
    func didReceive(stakingPool: StakingPool?) { pools.append(stakingPool) }
    func didReceive(palletIdResult: Result<Data, Error>) { palletResults.append(palletIdResult) }
    func didReceive(poolAccountInfo: AccountInfo?) { poolAccountInfos.append(poolAccountInfo) }
    func didReceive(existentialDepositResult: Result<BigUInt, Error>) { existentialDeposits.append(existentialDepositResult) }
    func didReceive(nomination: Nomination?) { nominations.append(nomination) }
    func didReceiveError(_ error: StakingPoolMainError) { errors.append(error) }
    func didReceive(pendingRewards: BigUInt?) { self.pendingRewards.append(pendingRewards) }
    func didReceive(pendingRewardsError: Error) { pendingRewardsErrors.append(pendingRewardsError) }
}

final class CovCPMMainIntAdapterSpy: AccountInfoSubscriptionAdapterProtocol {
    private(set) var subscribedAccounts: [AccountId] = []

    func subscribe(
        chainAsset _: ChainAsset,
        accountId: AccountId,
        handler _: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {
        subscribedAccounts.append(accountId)
    }

    func subscribe(chainsAssets _: [ChainAsset], handler _: AccountInfoSubscriptionAdapterHandler?, deliveryOn _: DispatchQueue?, notifyJustWhenUpdated _: Bool) {}
    func reset() {}
    func unsubscribe(chainAsset _: ChainAsset) {}
    func update(wallet _: fearless.MetaAccountModel) {}
}

final class CovCPMMainIntPoolFactoryStub: StakingPoolOperationFactoryProtocol {
    var membersResult: Result<StakingPoolMember?, Error> = .success(nil)
    var bondedPoolResult: Result<StakingPool?, Error> = .success(nil)
    var rewardsResult: Result<StakingPoolRewards?, Error> = .success(nil)
    var pendingRewardsResult: Result<BigUInt?, Error> = .success(BigUInt(3))
    private(set) var pendingRewardsRequests = 0
    private(set) var requestedPoolIds: [String] = []

    func fetchBondedPoolsOperation() -> CompoundOperationWrapper<[StakingPool]> { CovCPMMainIntWrap.wrapper(.success([])) }
    func fetchPoolMetadataOperation(poolId _: String) -> CompoundOperationWrapper<String?> { CovCPMMainIntWrap.wrapper(.success(nil)) }
    func fetchMinJoinBondOperation() -> CompoundOperationWrapper<BigUInt?> { CovCPMMainIntWrap.wrapper(.success(BigUInt(10))) }
    func fetchMinCreateBondOperation() -> CompoundOperationWrapper<BigUInt?> { CovCPMMainIntWrap.wrapper(.success(BigUInt(20))) }
    func fetchStakingPoolMembers(accountId _: AccountId) -> CompoundOperationWrapper<StakingPoolMember?> {
        CovCPMMainIntWrap.wrapper(membersResult)
    }

    func fetchMaxStakingPoolsCount() -> CompoundOperationWrapper<UInt32?> { CovCPMMainIntWrap.wrapper(.success(30)) }
    func fetchMaxPoolMembers() -> CompoundOperationWrapper<UInt32?> { CovCPMMainIntWrap.wrapper(.success(40)) }
    func fetchCounterForBondedPools() -> CompoundOperationWrapper<UInt32?> { CovCPMMainIntWrap.wrapper(.success(50)) }
    func fetchMaxPoolMembersPerPool() -> CompoundOperationWrapper<UInt32?> { CovCPMMainIntWrap.wrapper(.failure(CovCPMMainIntError())) }

    func fetchBondedPoolOperation(poolId: String) -> CompoundOperationWrapper<StakingPool?> {
        requestedPoolIds.append(poolId)
        return CovCPMMainIntWrap.wrapper(bondedPoolResult)
    }

    func fetchPoolRewardsOperation(poolId _: String) -> CompoundOperationWrapper<StakingPoolRewards?> { CovCPMMainIntWrap.wrapper(rewardsResult) }
    func fetchLastPoolId() -> CompoundOperationWrapper<UInt32?> { CovCPMMainIntWrap.wrapper(.success(nil)) }

    func fetchPendingRewards(accountId _: AccountId) -> CompoundOperationWrapper<BigUInt?> {
        pendingRewardsRequests += 1
        return CovCPMMainIntWrap.wrapper(pendingRewardsResult)
    }
}

final class CovCPMMainIntSubscriptionFactoryStub: RelaychainStakingLocalSubscriptionFactoryProtocol {
    private(set) var poolMemberRequests = 0
    private(set) var nominationRequests = 0
    private(set) var activeEraRequests = 0

    func getMinNominatorBondProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedBigUInt> { throw CovCPMMainIntError() }
    func getCounterForNominatorsProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> { throw CovCPMMainIntError() }
    func getMaxNominatorsCountProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> { throw CovCPMMainIntError() }
    func getNominationProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedNomination> {
        nominationRequests += 1
        throw CovCPMMainIntError()
    }

    func getValidatorProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedValidator> {
        throw CovCPMMainIntError()
    }

    func getLedgerInfoProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedLedgerInfo> {
        throw CovCPMMainIntError()
    }

    func getActiveEra(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedActiveEra> {
        activeEraRequests += 1
        throw CovCPMMainIntError()
    }

    func getCurrentEra(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedEraIndex> { throw CovCPMMainIntError() }
    func getPayee(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedPayee> { throw CovCPMMainIntError() }
    func getTotalReward(for _: AccountAddress, chain _: ChainModel, assetPrecision _: Int16) throws -> AnySingleValueProvider<TotalRewardItem> {
        throw CovCPMMainIntError()
    }

    func getStashItemProvider(for address: AccountAddress) -> StreamableProvider<StashItem> {
        SubstrateDataProviderFactory(facade: SubstrateDataStorageFacade.shared, operationManager: OperationManager())
            .createStashItemProvider(for: address)
    }

    func getPoolMembersProvider(for _: ChainAsset, accountId _: AccountId) throws -> AnyDataProvider<DecodedPoolMember> {
        poolMemberRequests += 1
        throw CovCPMMainIntError()
    }
}

final class CovCPMMainIntServicesStub: EraValidatorServiceProtocol, RewardCalculatorServiceProtocol, StakingServiceFactoryProtocol,
    EventCenterProtocol, StakingRemoteSubscriptionServiceProtocol, ExistentialDepositServiceProtocol {
    var infoResult: Result<EraStakersInfo, Error> = .success(EraStakersInfo(activeEra: 2, validators: []))
    private(set) var setupCount = 0
    private(set) var observersCount = 0
    private(set) var attachedIds: [UUID] = []
    private(set) var detachedIds: [UUID] = []

    func setup() { setupCount += 1 }
    func throttle() {}

    func fetchInfoOperation() -> BaseOperation<EraStakersInfo> {
        let operation = BaseOperation<EraStakersInfo>()
        operation.result = infoResult
        return operation
    }

    func fetchCalculatorOperation() -> BaseOperation<RewardCalculatorEngineProtocol> {
        let operation = BaseOperation<RewardCalculatorEngineProtocol>()
        operation.result = .failure(CovCPMMainIntError())
        return operation
    }

    func createEraValidatorService(for _: ChainModel) throws -> EraValidatorServiceProtocol { throw CovCPMMainIntError() }
    func createRewardCalculatorService(
        for _: ChainAsset,
        assetPrecision _: Int16,
        validatorService _: EraValidatorServiceProtocol
    ) throws -> RewardCalculatorServiceProtocol {
        throw CovCPMMainIntError()
    }

    func notify(with _: EventProtocol) {}
    func add(observer _: EventVisitorProtocol, dispatchIn _: DispatchQueue?) { observersCount += 1 }
    func remove(observer _: EventVisitorProtocol) {}

    func attachToGlobalData(for _: ChainModel.Id, queue _: DispatchQueue?, closure _: RemoteSubscriptionClosure?, stakingType _: StakingType?) -> UUID? {
        let identifier = UUID()
        attachedIds.append(identifier)
        return identifier
    }

    func detachFromGlobalData(
        for subscriptionId: UUID,
        chainId _: ChainModel.Id,
        queue _: DispatchQueue?,
        closure _: RemoteSubscriptionClosure?,
        stakingType _: StakingType?
    ) {
        detachedIds.append(subscriptionId)
    }

    func fetchExistentialDeposit(chainAsset _: ChainAsset, completion: @escaping (Result<BigUInt, Error>) -> Void) {
        completion(.success(BigUInt(9)))
    }
}

final class CovCPMMainIntAccountServicesStub: PoolStakingAccountUpdatingServiceProtocol, StakingAccountUpdatingServiceProtocol,
    AccountOperationFactoryProtocol {
    var shouldThrow = false
    private(set) var setupAccounts: [AccountId] = []
    private(set) var clearCount = 0
    private(set) var requestedPoolAccounts: [Data] = []

    func setupSubscription(for accountId: AccountId, chainAsset _: ChainAsset, chainFormat _: ChainFormat, stakingType _: StakingType) throws {
        setupAccounts.append(accountId)
        if shouldThrow {
            throw CovCPMMainIntError()
        }
    }

    func clearSubscription() { clearCount += 1 }

    func createGenisisHashOperation() -> BaseOperation<String> { BaseOperation<String>() }
    func createBlockHashOperation(_: UInt32) -> BaseOperation<String> { BaseOperation<String>() }
    func createAccountInfoFetchOperation(_ accountId: Data) -> CompoundOperationWrapper<AccountInfo?> {
        requestedPoolAccounts.append(accountId)
        return CovCPMMainIntWrap.wrapper(.success(nil))
    }
}

final class CovCPMMainIntValidatorFactoryStub: ValidatorOperationFactoryProtocol {
    func nomination(accountId _: AccountId) -> CompoundOperationWrapper<Nomination?> { CovCPMMainIntWrap.wrapper(.success(nil)) }
    func fetchAllValidators() -> CompoundOperationWrapper<[ElectedValidatorInfo]> { CovCPMMainIntWrap.wrapper(.success([])) }
    func allElectedOperation() -> CompoundOperationWrapper<[ElectedValidatorInfo]> { CovCPMMainIntWrap.wrapper(.success([])) }
    func allSelectedOperation(by _: Nomination, nominatorAddress _: AccountAddress) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        CovCPMMainIntWrap.wrapper(.success([]))
    }

    func activeValidatorsOperation(for _: AccountAddress) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        CovCPMMainIntWrap.wrapper(.success([]))
    }

    func pendingValidatorsOperation(for _: [AccountId]) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        CovCPMMainIntWrap.wrapper(.success([]))
    }

    func wannabeValidatorsOperation(for _: [AccountId]) -> CompoundOperationWrapper<[SelectedValidatorInfo]> {
        CovCPMMainIntWrap.wrapper(.success([]))
    }
}

final class CovCPMMainIntChainRegistryStub: ChainRegistryProtocol {
    var availableChainIds: Set<ChainModel.Id>? { nil }
    var availableChains: [ChainModel] { [] }
    var chainsTypesMap: [String: Data] { [:] }

    func resetConnection(for _: ChainModel.Id) {}
    func retryConnection(for _: ChainModel.Id) {}
    func getConnection(for _: ChainModel.Id) -> ChainConnection? { nil }
    func getEthereumConnection(for _: ChainModel.Id) -> Web3.Eth? { nil }
    func getTonApiClientFactory() throws -> TonAPIClientFactory { throw CovCPMMainIntError() }
    func getRuntimeProvider(for _: ChainModel.Id) -> RuntimeProviderProtocol? { nil }
    func getChain(for _: ChainModel.Id) -> ChainModel? { nil }
    func chainsSubscribe(_: AnyObject, runningInQueue _: DispatchQueue, updateClosure _: @escaping ([DataProviderChange<ChainModel>]) -> Void) {}
    func chainsUnsubscribe(_: AnyObject) {}
    func syncUp() {}
    func performHotBoot() {}
    func performColdBoot() {}
    func subscribeToChains() {}
}

final class CovCPMMainIntCountdownFactoryStub: EraCountdownOperationFactoryProtocol {
    func fetchCountdownOperationWrapper(for _: ChainConnection, runtimeService _: RuntimeCodingServiceProtocol) -> CompoundOperationWrapper<EraCountdown> {
        CovCPMMainIntWrap.wrapper(.failure(CovCPMMainIntError()))
    }
}

final class CovCPMPoolMainInteractorTests: XCTestCase {
    private var chainAsset: ChainAsset!
    private var wallet: fearless.MetaAccountModel!
    private var adapter: CovCPMMainIntAdapterSpy!
    private var poolFactory: CovCPMMainIntPoolFactoryStub!
    private var subscriptionFactory: CovCPMMainIntSubscriptionFactoryStub!
    private var services: CovCPMMainIntServicesStub!
    private var accountServices: CovCPMMainIntAccountServicesStub!
    private var commonSettings: InMemorySettingsManager!
    private var output: CovCPMMainIntOutputSpy!

    override func setUp() {
        super.setUp()
        let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        chainAsset = ChainAsset(chain: chain, asset: asset)
        wallet = AccountGenerator.generateMetaAccount()
        adapter = CovCPMMainIntAdapterSpy()
        poolFactory = CovCPMMainIntPoolFactoryStub()
        subscriptionFactory = CovCPMMainIntSubscriptionFactoryStub()
        services = CovCPMMainIntServicesStub()
        accountServices = CovCPMMainIntAccountServicesStub()
        commonSettings = InMemorySettingsManager()
        output = CovCPMMainIntOutputSpy()
    }

    override func tearDown() {
        chainAsset = nil
        wallet = nil
        adapter = nil
        poolFactory = nil
        subscriptionFactory = nil
        services = nil
        accountServices = nil
        commonSettings = nil
        output = nil
        super.tearDown()
    }

    private func makeInteractor(selectedWallet: fearless.MetaAccountModel?) -> StakingPoolMainInteractor {
        let selectedWalletSettings = SelectedWalletSettings(storageFacade: UserDataStorageFacade.shared, operationQueue: OperationQueue())
        selectedWalletSettings.internalValue = selectedWallet
        return StakingPoolMainInteractor(
            accountInfoSubscriptionAdapter: adapter,
            selectedWalletSettings: selectedWalletSettings,
            settings: StakingAssetSettings(
                storageFacade: SubstrateDataStorageFacade.shared,
                settings: InMemorySettingsManager(),
                operationQueue: OperationQueue(),
                wallet: wallet
            ),
            stakingPoolOperationFactory: poolFactory,
            rewardCalculationService: services,
            chainAsset: chainAsset,
            wallet: wallet,
            operationManager: OperationManager(),
            stakingServiceFactory: services,
            logger: nil,
            commonSettings: commonSettings,
            eraValidatorService: services,
            chainRegistry: CovCPMMainIntChainRegistryStub(),
            eraCountdownOperationFactory: CovCPMMainIntCountdownFactoryStub(),
            eventCenter: services,
            stakingLocalSubscriptionFactory: subscriptionFactory,
            poolStakingAccountUpdatingService: accountServices,
            accountOperationFactory: accountServices,
            existentialDepositService: services,
            validatorOperationFactory: CovCPMMainIntValidatorFactoryStub(),
            stakingAccountUpdatingService: accountServices,
            stakingRemoteSubscriptionService: services
        )
    }

    private func spin(until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    private func member(poolId: UInt32) throws -> StakingPoolMember {
        let json: [String: Any] = ["poolId": "\(poolId)", "points": "10", "lastRecordedRewardCounter": "0", "unbondingEras": []]
        let data = try JSONSerialization.data(withJSONObject: json)
        return try JSONDecoder().decode(StakingPoolMember.self, from: data)
    }

    func testSetupLoadsChainAssetData() throws {
        poolFactory.membersResult = .success(try member(poolId: 4))
        let interactor = makeInteractor(selectedWallet: wallet)

        interactor.setup(with: output)
        spin {
            !output.networkInfos.isEmpty && !output.countdownResults.isEmpty && !output.pendingRewards.isEmpty
                && output.stakeInfos.count >= 3 && output.engineCalls >= 3
        }

        XCTAssertEqual(output.chainAssets.count, 1)
        XCTAssertEqual(output.pools.count, 1)
        XCTAssertEqual(output.poolAccountInfos.count, 1)
        XCTAssertEqual(adapter.subscribedAccounts, [wallet.substrateAccountId].compactMap { $0 })
        XCTAssertEqual(subscriptionFactory.poolMemberRequests, 1)
        XCTAssertEqual(subscriptionFactory.activeEraRequests, 1)
        XCTAssertEqual(accountServices.setupAccounts.count, 1)
        XCTAssertEqual(accountServices.clearCount, 2)
        XCTAssertEqual(services.setupCount, 1)
        XCTAssertEqual(services.observersCount, 1)
        XCTAssertEqual(services.attachedIds.count, 1)
        XCTAssertTrue(services.detachedIds.isEmpty)
        XCTAssertEqual(output.existentialDeposits.count, 1)
        guard case .failure? = output.palletResults.first, case .failure? = output.countdownResults.first else {
            return XCTFail("expected failures without runtime provider")
        }
        let info = try XCTUnwrap(output.networkInfos.first)
        XCTAssertEqual(info.minJoinBond, BigUInt(10))
        XCTAssertEqual(info.minCreateBond, BigUInt(20))
        XCTAssertEqual(info.possiblePoolsCount, 30)
        XCTAssertEqual(info.maxPoolsMembers, 40)
        XCTAssertEqual(info.existingPoolsCount, 50)
        XCTAssertNil(info.maxMembersInPool)
        XCTAssertEqual(output.eraStakers.first?.activeEra, 2)
        XCTAssertEqual(output.pendingRewards.first ?? nil, BigUInt(3))
        XCTAssertEqual(output.stakeInfos.compactMap { $0 }.first?.poolId.value, 4)
    }

    func testRepeatedUpdateDetachesPreviousRemoteSubscription() {
        let interactor = makeInteractor(selectedWallet: wallet)
        interactor.setup(with: output)
        let firstId = services.attachedIds.first

        interactor.updateWithChainAsset(chainAsset)

        XCTAssertEqual(services.detachedIds.first, firstId)
        XCTAssertEqual(services.attachedIds.count, 2)
        XCTAssertEqual(output.chainAssets.count, 2)
    }

    func testSetupWithoutSelectedWalletSkipsAccountSubscriptions() {
        let interactor = makeInteractor(selectedWallet: nil)

        interactor.setup(with: output)
        spin { !output.networkInfos.isEmpty }

        XCTAssertTrue(adapter.subscribedAccounts.isEmpty)
        XCTAssertEqual(subscriptionFactory.poolMemberRequests, 0)
        XCTAssertEqual(poolFactory.pendingRewardsRequests, 0)
        XCTAssertEqual(output.chainAssets.count, 1)
    }

    func testOperationFailuresAreReported() {
        poolFactory.membersResult = .failure(CovCPMMainIntError())
        poolFactory.pendingRewardsResult = .failure(CovCPMMainIntError())
        services.infoResult = .failure(CovCPMMainIntError())
        let interactor = makeInteractor(selectedWallet: wallet)

        interactor.setup(with: output)
        spin { output.errors.count >= 3 && !output.pendingRewardsErrors.isEmpty }

        XCTAssertTrue(output.errors.contains { if case .stakeInfoError = $0 { return true } else { return false } })
        XCTAssertTrue(output.errors.contains { if case .eraStakersInfoError = $0 { return true } else { return false } })
        XCTAssertFalse(output.pendingRewardsErrors.isEmpty)
        XCTAssertTrue(output.countdownResults.isEmpty)
    }

    func testFetchPoolBalanceAndNomination() {
        let interactor = makeInteractor(selectedWallet: nil)
        interactor.setup(with: output)
        let account = Data(repeating: 6, count: 32)

        interactor.fetchPoolBalance(poolRewardAccountId: account)
        spin { output.poolAccountInfos.count >= 2 }
        XCTAssertEqual(accountServices.requestedPoolAccounts, [account])

        interactor.fetchPoolNomination(poolStashAccountId: account)
        XCTAssertEqual(accountServices.setupAccounts, [account])
        XCTAssertEqual(subscriptionFactory.nominationRequests, 1)
        XCTAssertTrue(output.errors.isEmpty)

        accountServices.shouldThrow = true
        interactor.fetchPoolNomination(poolStashAccountId: account)
        guard case .nominationError? = output.errors.last else {
            return XCTFail("expected nomination error")
        }
    }

    func testAccountInfoHandlerFiltersByChainAssetAndAccount() throws {
        let interactor = makeInteractor(selectedWallet: nil)
        interactor.setup(with: output)
        let accountId = try XCTUnwrap(wallet.substrateAccountId)
        let other = ChainAsset(
            chain: ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0),
            asset: chainAsset.asset
        )

        interactor.handleAccountInfo(result: .success(nil), accountId: accountId, chainAsset: other)
        interactor.handleAccountInfo(result: .success(nil), accountId: Data(repeating: 1, count: 32), chainAsset: chainAsset)
        XCTAssertTrue(output.accountInfos.isEmpty)

        interactor.handleAccountInfo(result: .success(nil), accountId: accountId, chainAsset: chainAsset)
        interactor.handleAccountInfo(result: .failure(CovCPMMainIntError()), accountId: accountId, chainAsset: chainAsset)

        XCTAssertEqual(output.accountInfos.count, 1)
        guard case .balanceError? = output.errors.last else {
            return XCTFail("expected balance error")
        }
    }

    func testPoolMemberHandler() throws {
        poolFactory.rewardsResult = .failure(CovCPMMainIntError())
        let interactor = makeInteractor(selectedWallet: nil)
        interactor.setup(with: output)
        spin { output.stakeInfos.count >= 3 }
        let accountId = try XCTUnwrap(wallet.substrateAccountId)
        let baseline = output.stakeInfos.count

        interactor.handlePoolMember(result: .success(try member(poolId: 8)), accountId: Data(repeating: 1, count: 32), chainId: chainAsset.chain.chainId)
        interactor.handlePoolMember(result: .success(try member(poolId: 8)), accountId: accountId, chainId: chainAsset.chain.chainId)
        interactor.handlePoolMember(result: .failure(CovCPMMainIntError()), accountId: accountId, chainId: chainAsset.chain.chainId)
        spin {
            output.stakeInfos.count > baseline && output.errors.contains { if case .poolRewardsError = $0 { return true } else { return false } }
                && output.errors.contains { if case .stakeInfoError = $0 { return true } else { return false } }
        }

        XCTAssertEqual(poolFactory.requestedPoolIds, ["8"])
        XCTAssertEqual(output.stakeInfos.last??.poolId.value, 8)
        XCTAssertTrue(output.errors.contains { if case .poolRewardsError = $0 { return true } else { return false } })
        XCTAssertTrue(output.errors.contains { if case .stakeInfoError = $0 { return true } else { return false } })
    }

    func testNominationAndActiveEraHandlers() throws {
        let interactor = makeInteractor(selectedWallet: nil)
        interactor.setup(with: output)

        interactor.handleNomination(result: .success(nil), accountId: Data(), chainId: chainAsset.chain.chainId)
        interactor.handleNomination(result: .failure(CovCPMMainIntError()), accountId: Data(), chainId: chainAsset.chain.chainId)
        interactor.handleActiveEra(result: .success(ActiveEraInfo(index: 77)), chainId: chainAsset.chain.chainId)
        interactor.handleActiveEra(result: .failure(CovCPMMainIntError()), chainId: chainAsset.chain.chainId)

        XCTAssertEqual(output.nominations.count, 1)
        XCTAssertEqual(output.eras.first ?? nil, 77)
        XCTAssertTrue(output.errors.contains { if case .nominationError = $0 { return true } else { return false } })
        XCTAssertTrue(output.errors.contains { if case .eraStakersInfoError = $0 { return true } else { return false } })
    }

    func testSettingsAndSameChainAssetSave() {
        let interactor = makeInteractor(selectedWallet: nil)
        interactor.setup(with: output)
        let count = output.chainAssets.count

        interactor.saveNetworkInfoViewExpansion(isExpanded: false)
        interactor.save(chainAsset: chainAsset)

        XCTAssertFalse(commonSettings.stakingNetworkExpansion)
        XCTAssertEqual(output.chainAssets.count, count)
    }

    func testDeinitDetachesRemoteSubscription() {
        var interactor: StakingPoolMainInteractor? = makeInteractor(selectedWallet: nil)
        interactor?.setupChainRemoteSubscription()
        let attached = services.attachedIds.first

        interactor = nil

        XCTAssertNil(interactor)
        XCTAssertEqual(services.detachedIds, [attached].compactMap { $0 })
    }
}
