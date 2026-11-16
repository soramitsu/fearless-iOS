import XCTest
import SSFModels
import BigInt
import RobinHood
import SSFUtils
import SSFRuntimeCodingService
@testable import fearless

enum CovCABSFSError: Error {
    case failed
}

final class CovCABSFSRuntime: RuntimeProviderProtocol {
    var snapshot: RuntimeSnapshot? { nil }
    var runtimeSpecVersion: RuntimeSpecVersion { .defaultVersion }

    func setup() {}
    func cleanup() {}
    func setupHot() {}

    func readySnapshot() async throws -> RuntimeSnapshot {
        throw CovCABSFSError.failed
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        let operation = BaseOperation<RuntimeCoderFactoryProtocol>()
        operation.result = .failure(CovCABSFSError.failed)
        return operation
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        throw CovCABSFSError.failed
    }
}

final class CovCABSFSEngine: JSONRPCEngine {
    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }

    func callMethod<P: Codable, T: Decodable>(
        _: String,
        params _: P?,
        options _: JSONRPCOptions,
        completion _: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        throw CovCABSFSError.failed
    }

    func subscribe<P: Codable, T: Decodable>(
        _: String,
        params _: P?,
        updateClosure _: @escaping (T) -> Void,
        failureClosure _: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        throw CovCABSFSError.failed
    }

    func cancelForIdentifier(_: UInt16) {}
    func generateRequestId() -> UInt16 { 1 }
    func addSubscription(_: JSONRPCSubscribing) {}
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_: UInt16) throws {}
}

final class CovCABSFSStakingFactory: RelaychainStakingLocalSubscriptionFactoryProtocol {
    func getMinNominatorBondProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedBigUInt> { throw CovCABSFSError.failed }
    func getCounterForNominatorsProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> { throw CovCABSFSError.failed }
    func getMaxNominatorsCountProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> { throw CovCABSFSError.failed }

    func getNominationProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedNomination> {
        throw CovCABSFSError.failed
    }

    func getValidatorProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedValidator> {
        throw CovCABSFSError.failed
    }

    func getLedgerInfoProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedLedgerInfo> {
        throw CovCABSFSError.failed
    }

    func getActiveEra(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedActiveEra> { throw CovCABSFSError.failed }
    func getCurrentEra(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedEraIndex> { throw CovCABSFSError.failed }

    func getPayee(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedPayee> {
        throw CovCABSFSError.failed
    }

    func getTotalReward(for _: AccountAddress, chain _: ChainModel, assetPrecision _: Int16) throws -> AnySingleValueProvider<TotalRewardItem> {
        throw CovCABSFSError.failed
    }

    func getStashItemProvider(for address: AccountAddress) -> StreamableProvider<StashItem> {
        SubstrateDataProviderFactory(facade: SubstrateDataStorageFacade.shared, operationManager: OperationManager())
            .createStashItemProvider(for: address)
    }

    func getPoolMembersProvider(for _: ChainAsset, accountId _: AccountId) throws -> AnyDataProvider<DecodedPoolMember> {
        throw CovCABSFSError.failed
    }
}

final class CovCABSFSRepository: DataProviderRepositoryProtocol {
    typealias Model = fearless.MetaAccountModel

    let models: [fearless.MetaAccountModel]

    init(models: [fearless.MetaAccountModel]) {
        self.models = models
    }

    private func failing<T>() -> BaseOperation<T> {
        let operation = BaseOperation<T>()
        operation.result = .failure(CovCABSFSError.failed)
        return operation
    }

    func fetchOperation(by _: @escaping () throws -> [String], options _: RepositoryFetchOptions) -> BaseOperation<[Model]> { failing() }
    func fetchOperation(by _: @escaping () throws -> String, options _: RepositoryFetchOptions) -> BaseOperation<Model?> { failing() }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[Model]> {
        let operation = BaseOperation<[Model]>()
        operation.result = .success(models)
        return operation
    }

    func fetchOperation(by _: RepositorySliceRequest, options _: RepositoryFetchOptions) -> BaseOperation<[Model]> { failing() }
    func saveOperation(_: @escaping () throws -> [Model], _: @escaping () throws -> [String]) -> BaseOperation<Void> { failing() }
    func saveBatchOperation(_: @escaping () throws -> [Model], _: @escaping () throws -> [String]) -> BaseOperation<Void> { failing() }
    func replaceOperation(_: @escaping () throws -> [Model]) -> BaseOperation<Void> { failing() }
    func fetchCountOperation() -> BaseOperation<Int> { failing() }
    func deleteAllOperation() -> BaseOperation<Void> { failing() }
}

final class CovCABSFSExtrinsicService: ExtrinsicServiceProtocol {
    var feeResult: Result<RuntimeDispatchInfo, Error> = .success(RuntimeDispatchInfo(feeValue: BigUInt(2000)))

    func estimateFee(_: @escaping ExtrinsicBuilderClosure, runningIn _: DispatchQueue, completion completionClosure: @escaping EstimateFeeClosure) {
        completionClosure(feeResult)
    }

    func estimateFee(
        _: @escaping ExtrinsicBuilderIndexedClosure,
        runningIn _: DispatchQueue,
        numberOfExtrinsics _: Int,
        completion completionClosure: @escaping EstimateFeeIndexedClosure
    ) {
        completionClosure([])
    }

    func submit(
        _: @escaping ExtrinsicBuilderClosure,
        signer _: SigningWrapperProtocol,
        runningIn _: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitClosure
    ) {
        completionClosure(.failure(CovCABSFSError.failed))
    }

    func submit(
        _: @escaping ExtrinsicBuilderIndexedClosure,
        signer _: SigningWrapperProtocol,
        runningIn _: DispatchQueue,
        numberOfExtrinsics _: Int,
        completion completionClosure: @escaping ExtrinsicSubmitIndexedClosure
    ) {
        completionClosure([])
    }

    func submitAndWatch(
        _: @escaping ExtrinsicBuilderClosure,
        signer _: SigningWrapperProtocol,
        runningIn _: DispatchQueue,
        completion completionClosure: @escaping ExtrinsicSubmitAndWatchClosure
    ) {
        completionClosure(.failure(CovCABSFSError.failed), nil)
    }
}

final class CovCABSFSServices: NetworkStakingInfoOperationFactoryProtocol, EraValidatorServiceProtocol,
    ExistentialDepositServiceProtocol, EraCountdownOperationFactoryProtocol, RewardCalculatorServiceProtocol {
    var networkInfoResult: Result<NetworkStakingInfo, Error> = .failure(CovCABSFSError.failed)
    var existentialDepositResult: Result<BigUInt, Error> = .success(BigUInt(1_000_000_000))
    var countdownResult: Result<EraCountdown, Error> = .failure(CovCABSFSError.failed)
    var calculatorResult: Result<RewardCalculatorEngineProtocol, Error> = .failure(CovCABSFSError.failed)
    private(set) var setupCalls = 0

    func networkStakingOperation(
        for _: EraValidatorServiceProtocol,
        runtimeService _: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<NetworkStakingInfo> {
        let operation = BaseOperation<NetworkStakingInfo>()
        operation.result = networkInfoResult
        return CompoundOperationWrapper(targetOperation: operation)
    }

    func fetchInfoOperation() -> BaseOperation<EraStakersInfo> {
        let operation = BaseOperation<EraStakersInfo>()
        operation.result = .failure(CovCABSFSError.failed)
        return operation
    }

    func setup() { setupCalls += 1 }
    func throttle() {}

    func fetchExistentialDeposit(chainAsset _: ChainAsset, completion: @escaping (Result<BigUInt, Error>) -> Void) {
        completion(existentialDepositResult)
    }

    func fetchCountdownOperationWrapper(
        for _: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<EraCountdown> {
        let operation = BaseOperation<EraCountdown>()
        operation.result = countdownResult
        return CompoundOperationWrapper(targetOperation: operation)
    }

    func fetchCalculatorOperation() -> BaseOperation<RewardCalculatorEngineProtocol> {
        let operation = BaseOperation<RewardCalculatorEngineProtocol>()
        operation.result = calculatorResult
        return operation
    }
}

final class CovCABSFSAmountOutput: StakingAmountRelaychainStrategyOutput {
    private(set) var errors: [Error] = []
    private(set) var minimalBalances: [BigUInt?] = []
    private(set) var minimumBonds: [BigUInt?] = []
    private(set) var counters: [UInt32?] = []
    private(set) var maxCounts: [UInt32?] = []
    private(set) var paymentInfos: [RuntimeDispatchInfo] = []
    private(set) var networkInfos: [NetworkStakingInfo] = []
    private(set) var networkErrors: [Error] = []
    private(set) var maxNominations: [Int] = []

    func didReceive(error: Error) { errors.append(error) }
    func didReceive(minimalBalance: BigUInt?) { minimalBalances.append(minimalBalance) }
    func didReceive(minimumBond: BigUInt?) { minimumBonds.append(minimumBond) }
    func didReceive(counterForNominators: UInt32?) { counters.append(counterForNominators) }
    func didReceive(maxNominatorsCount: UInt32?) { maxCounts.append(maxNominatorsCount) }
    func didReceive(paymentInfo: RuntimeDispatchInfo) { paymentInfos.append(paymentInfo) }
    func didReceive(networkStakingInfo: NetworkStakingInfo) { networkInfos.append(networkStakingInfo) }
    func didReceive(networkStakingInfoError: Error) { networkErrors.append(networkStakingInfoError) }
    func didReceive(maxNominations: Int) { self.maxNominations.append(maxNominations) }
}

enum CovCABSFSFixtures {
    static func spin(until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    static func networkInfo() -> NetworkStakingInfo {
        .relaychain(
            baseInfo: BaseStakingInfo(lockUpPeriod: 7, minimalBalance: 10, minStakeAmongActiveNominators: 0),
            relaychainInfo: RelaychainStakingInfo(
                stakingDuration: StakingDuration(session: 1, era: 2, unlocking: 3),
                totalStake: 100,
                activeNominatorsCount: 5
            )
        )
    }

    static func walletWithoutSubstrate() -> fearless.MetaAccountModel {
        fearless.MetaAccountModel(
            metaId: UUID().uuidString,
            name: "empty",
            substrateAccountId: nil,
            substrateCryptoType: 0,
            substratePublicKey: nil,
            ethereumAddress: nil,
            ethereumPublicKey: nil,
            chainAccounts: [],
            assetKeysOrder: nil,
            canExportEthereumMnemonic: false,
            unusedChainIds: nil,
            selectedCurrency: Currency.defaultCurrency(),
            networkManagmentFilter: nil,
            assetsVisibility: [],
            hasBackup: true,
            favouriteChainIds: []
        )
    }
}

final class CovCABStakingAmountStrategyTests: XCTestCase {
    private var output: CovCABSFSAmountOutput!
    private var services: CovCABSFSServices!
    private var extrinsicService: CovCABSFSExtrinsicService!
    private var strategy: StakingAmountRelaychainStrategy!
    private var chain: ChainModel!

    override func setUp() {
        super.setUp()
        chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        output = CovCABSFSAmountOutput()
        services = CovCABSFSServices()
        extrinsicService = CovCABSFSExtrinsicService()
        strategy = StakingAmountRelaychainStrategy(
            chainAsset: ChainAsset(chain: chain, asset: asset),
            runtimeService: CovCABSFSRuntime(),
            operationManager: OperationManager(),
            stakingLocalSubscriptionFactory: CovCABSFSStakingFactory(),
            extrinsicService: extrinsicService,
            output: output,
            eraInfoOperationFactory: services,
            eraValidatorService: services,
            existentialDepositService: services,
            rewardChainAsset: nil
        )
    }

    override func tearDown() {
        strategy = nil
        extrinsicService = nil
        services = nil
        output = nil
        chain = nil
        super.tearDown()
    }

    func testSetupReportsDepositConstantAndNetworkInfoFailure() {
        strategy.setup()

        XCTAssertEqual(services.setupCalls, 1)
        XCTAssertEqual(output.minimalBalances, [BigUInt(1_000_000_000)])

        CovCABSFSFixtures.spin { !output.networkErrors.isEmpty && !output.errors.isEmpty }
        XCTAssertEqual(output.networkErrors.count, 1)
        XCTAssertEqual(output.errors.count, 1)
        XCTAssertTrue(output.maxNominations.isEmpty)
    }

    func testSetupDeliversNetworkInfoAndDepositError() {
        services.networkInfoResult = .success(CovCABSFSFixtures.networkInfo())
        services.existentialDepositResult = .failure(CovCABSFSError.failed)

        strategy.setup()
        CovCABSFSFixtures.spin { !output.networkInfos.isEmpty }

        XCTAssertEqual(output.networkInfos.first?.baseInfo.lockUpPeriod, 7)
        XCTAssertTrue(output.minimalBalances.isEmpty)
        XCTAssertGreaterThanOrEqual(output.errors.count, 1)
    }

    func testEstimateFeeForwardsResult() {
        strategy.estimateFee { $0 }
        XCTAssertEqual(output.paymentInfos.first?.fee, "2000")

        extrinsicService.feeResult = .failure(CovCABSFSError.failed)
        strategy.estimateFee { $0 }
        XCTAssertEqual(output.errors.count, 1)
    }

    func testSubscriptionHandlersForwardValuesAndErrors() {
        strategy.handleMinNominatorBond(result: .success(BigUInt(5)), chainId: chain.chainId)
        strategy.handleMinNominatorBond(result: .failure(CovCABSFSError.failed), chainId: chain.chainId)
        strategy.handleMaxNominatorsCount(result: .success(9), chainId: chain.chainId)
        strategy.handleMaxNominatorsCount(result: .failure(CovCABSFSError.failed), chainId: chain.chainId)
        strategy.handleCounterForNominators(result: .success(3), chainId: chain.chainId)
        strategy.handleCounterForNominators(result: .failure(CovCABSFSError.failed), chainId: chain.chainId)

        XCTAssertEqual(output.minimumBonds, [BigUInt(5)])
        XCTAssertEqual(output.maxCounts, [9])
        XCTAssertEqual(output.counters, [3])
        XCTAssertEqual(output.errors.count, 3)
    }
}

final class CovCABSFSStrategy: StakingAmountStrategy {
    private(set) var setupCalls = 0
    private(set) var estimateCalls = 0

    func setup() { setupCalls += 1 }
    func estimateFee(extrinsicBuilderClosure _: @escaping ExtrinsicBuilderClosure) { estimateCalls += 1 }
}

final class CovCABSFSAdapter: AccountInfoSubscriptionAdapterProtocol {
    private(set) var subscribedAccountIds: [AccountId] = []

    func subscribe(
        chainAsset _: ChainAsset,
        accountId: AccountId,
        handler _: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {
        subscribedAccountIds.append(accountId)
    }

    func subscribe(
        chainsAssets _: [ChainAsset],
        handler _: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {}

    func reset() {}
    func unsubscribe(chainAsset _: ChainAsset) {}
    func update(wallet _: fearless.MetaAccountModel) {}
}

final class CovCABSFSInteractorOutput: StakingAmountInteractorOutputProtocol {
    private(set) var accounts: [[fearless.ChainAccountResponse]] = []
    private(set) var balances: [AccountData?] = []
    private(set) var errors: [Error] = []
    private(set) var calculators = 0
    private(set) var calculatorErrors: [Error] = []

    func didReceive(accounts: [fearless.ChainAccountResponse]) { self.accounts.append(accounts) }
    func didReceive(balance: AccountData?) { balances.append(balance) }
    func didReceive(error: Error) { errors.append(error) }
    func didReceive(calculator _: RewardCalculatorEngineProtocol) { calculators += 1 }
    func didReceive(calculatorError: Error) { calculatorErrors.append(calculatorError) }
}

final class CovCABStakingAmountInteractorTests: XCTestCase {
    private var output: CovCABSFSInteractorOutput!
    private var services: CovCABSFSServices!
    private var adapter: CovCABSFSAdapter!
    private var strategy: CovCABSFSStrategy!
    private var interactor: StakingAmountInteractor!
    private var chain: ChainModel!
    private var wallet: fearless.MetaAccountModel!

    override func setUp() {
        super.setUp()
        chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        wallet = AccountGenerator.generateMetaAccount()
        output = CovCABSFSInteractorOutput()
        services = CovCABSFSServices()
        adapter = CovCABSFSAdapter()
        strategy = CovCABSFSStrategy()
        interactor = StakingAmountInteractor(
            accountInfoSubscriptionAdapter: adapter,
            rewardService: services,
            runtimeService: CovCABSFSRuntime(),
            operationManager: OperationManager(),
            chainAsset: ChainAsset(chain: chain, asset: asset),
            wallet: wallet,
            accountRepository: AnyDataProviderRepository(CovCABSFSRepository(models: [wallet])),
            strategy: strategy
        )
        interactor.presenter = output
    }

    override func tearDown() {
        interactor = nil
        strategy = nil
        adapter = nil
        services = nil
        output = nil
        chain = nil
        wallet = nil
        super.tearDown()
    }

    func testSetupSubscribesAndReportsCalculatorFailure() throws {
        interactor.setup()
        CovCABSFSFixtures.spin { !output.calculatorErrors.isEmpty }

        let account = try XCTUnwrap(wallet.fetch(for: chain.accountRequest()))
        XCTAssertEqual(adapter.subscribedAccountIds, [account.accountId])
        XCTAssertEqual(strategy.setupCalls, 1)
        XCTAssertEqual(services.setupCalls, 1)
        XCTAssertEqual(output.calculatorErrors.count, 1)
    }

    func testSetupDeliversCalculator() {
        services.calculatorResult = .success(WestendStub.rewardCalculator)

        interactor.setup()
        CovCABSFSFixtures.spin { output.calculators > 0 }

        XCTAssertEqual(output.calculators, 1)
        XCTAssertTrue(output.calculatorErrors.isEmpty)
    }

    func testFetchAccountsAndEstimateFee() throws {
        interactor.fetchAccounts()
        CovCABSFSFixtures.spin { !output.accounts.isEmpty }

        let account = try XCTUnwrap(wallet.fetch(for: chain.accountRequest()))
        XCTAssertEqual(output.accounts.first, [account])

        interactor.estimateFee { $0 }
        XCTAssertEqual(strategy.estimateCalls, 1)
    }

    func testAccountInfoHandlerForwardsBalanceOrError() throws {
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        let chainAsset = ChainAsset(chain: chain, asset: asset)
        let data = AccountData(free: 7, reserved: 0, frozen: 0, flags: 0)

        interactor.handleAccountInfo(
            result: .success(AccountInfo(nonce: 0, consumers: 0, providers: 0, data: data)),
            accountId: Data(repeating: 1, count: 32),
            chainAsset: chainAsset
        )
        interactor.handleAccountInfo(result: .success(nil), accountId: Data(repeating: 1, count: 32), chainAsset: chainAsset)
        interactor.handleAccountInfo(result: .failure(CovCABSFSError.failed), accountId: Data(repeating: 1, count: 32), chainAsset: chainAsset)

        XCTAssertEqual(output.balances.count, 2)
        XCTAssertEqual(output.balances.first??.free, 7)
        XCTAssertNil(output.balances.last ?? nil)
        XCTAssertEqual(output.errors.count, 1)
    }
}

final class CovCABSFSBalanceOutput: StakingBalanceRelaychainStrategyOutput {
    private(set) var ledgers: [Result<StakingLedger?, Error>] = []
    private(set) var activeEras: [Result<EraIndex?, Error>] = []
    private(set) var stashItems: [Result<StashItem?, Error>] = []
    private(set) var controllers: [Result<fearless.ChainAccountResponse?, Error>] = []
    private(set) var stashes: [Result<fearless.ChainAccountResponse?, Error>] = []
    private(set) var countdowns: [Result<EraCountdown, Error>] = []

    func didReceive(ledgerResult: Result<StakingLedger?, Error>) { ledgers.append(ledgerResult) }
    func didReceive(activeEraResult: Result<EraIndex?, Error>) { activeEras.append(activeEraResult) }
    func didReceive(stashItemResult: Result<StashItem?, Error>) { stashItems.append(stashItemResult) }
    func didReceive(controllerResult: Result<fearless.ChainAccountResponse?, Error>) { controllers.append(controllerResult) }
    func didReceive(stashResult: Result<fearless.ChainAccountResponse?, Error>) { stashes.append(stashResult) }
    func didReceive(eraCountdownResult: Result<EraCountdown, Error>) { countdowns.append(eraCountdownResult) }
}

final class CovCABStakingBalanceStrategyTests: XCTestCase {
    private var output: CovCABSFSBalanceOutput!
    private var services: CovCABSFSServices!
    private var strategy: StakingBalanceRelaychainStrategy!
    private var chain: ChainModel!
    private var repoWallet: fearless.MetaAccountModel!

    override func setUp() {
        super.setUp()
        chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        repoWallet = AccountGenerator.generateMetaAccount()
        output = CovCABSFSBalanceOutput()
        services = CovCABSFSServices()
        strategy = StakingBalanceRelaychainStrategy(
            output: output,
            stakingLocalSubscriptionFactory: CovCABSFSStakingFactory(),
            runtimeCodingService: CovCABSFSRuntime(),
            operationManager: OperationManager(),
            eraCountdownOperationFactory: services,
            connection: CovCABSFSEngine(),
            accountRepository: AnyDataProviderRepository(CovCABSFSRepository(models: [repoWallet])),
            chainAsset: ChainAsset(chain: chain, asset: asset),
            wallet: CovCABSFSFixtures.walletWithoutSubstrate()
        )
    }

    override func tearDown() {
        strategy = nil
        services = nil
        output = nil
        chain = nil
        repoWallet = nil
        super.tearDown()
    }

    func testSetupFetchesEraCountdown() {
        services.countdownResult = .success(EraCountdown(
            activeEra: 1,
            currentEra: 1,
            eraLength: 6,
            sessionLength: 10,
            activeEraStartSessionIndex: 0,
            currentSessionIndex: 0,
            currentSlot: 0,
            genesisSlot: 0,
            blockCreationTime: 6000,
            createdAtDate: Date()
        ))

        strategy.setup()
        CovCABSFSFixtures.spin { !output.countdowns.isEmpty }

        XCTAssertEqual(try output.countdowns.first?.get().activeEra, 1)
    }

    func testActiveEraAndLedgerHandlers() {
        strategy.handleActiveEra(result: .success(ActiveEraInfo(index: 42)), chainId: chain.chainId)
        strategy.handleActiveEra(result: .failure(CovCABSFSError.failed), chainId: chain.chainId)
        strategy.handleLedgerInfo(result: .success(nil), accountId: Data(repeating: 1, count: 32), chainId: chain.chainId)

        XCTAssertEqual(try output.activeEras.first?.get(), 42)
        XCTAssertThrowsError(try output.activeEras.last?.get())
        XCTAssertEqual(output.ledgers.count, 1)

        CovCABSFSFixtures.spin { !output.countdowns.isEmpty }
        XCTAssertThrowsError(try output.countdowns.first?.get())
    }

    func testStashItemHandlerFetchesAccounts() throws {
        let repoAddress = try XCTUnwrap(repoWallet.fetch(for: chain.accountRequest())?.toAddress())
        let foreignAddress = try XCTUnwrap(AccountGenerator.generateMetaAccount().fetch(for: chain.accountRequest())?.toAddress())

        strategy.handleStashItem(result: .success(StashItem(stash: foreignAddress, controller: repoAddress)), for: repoAddress)
        CovCABSFSFixtures.spin { !output.controllers.isEmpty && !output.stashes.isEmpty }

        XCTAssertEqual(output.stashItems.count, 1)
        XCTAssertEqual(try output.controllers.first?.get()?.toAddress(), repoAddress)
        XCTAssertThrowsError(try output.stashes.first?.get())
    }

    func testStashItemNilAndFailure() {
        strategy.handleStashItem(result: .success(nil), for: "address")
        XCTAssertNil(try output.stashItems.first?.get())

        strategy.handleStashItem(result: .failure(CovCABSFSError.failed), for: "address")
        XCTAssertEqual(output.stashItems.count, 1)
        XCTAssertEqual(output.stashes.count, 1)
    }
}
