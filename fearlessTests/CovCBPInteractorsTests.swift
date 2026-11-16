import XCTest
import BigInt
import RobinHood
import IrohaCrypto
import SoraKeystore
import SSFModels
import SSFUtils
import SSFRuntimeCodingService
@testable import fearless

final class CovCBPINRepository<T: Identifiable>: DataProviderRepositoryProtocol {
    typealias Model = T
    var items: [T]

    init(items: [T]) { self.items = items }

    func fetchOperation(by _: @escaping () throws -> [String], options _: RepositoryFetchOptions) -> BaseOperation<[T]> {
        let items = self.items
        return ClosureOperation { items }
    }

    func fetchOperation(by _: @escaping () throws -> String, options _: RepositoryFetchOptions) -> BaseOperation<T?> {
        let items = self.items
        return ClosureOperation { items.first }
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[T]> {
        let items = self.items
        return ClosureOperation { items }
    }

    func fetchOperation(by _: RepositorySliceRequest, options _: RepositoryFetchOptions) -> BaseOperation<[T]> {
        let items = self.items
        return ClosureOperation { items }
    }

    func saveOperation(_: @escaping () throws -> [T], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation {}
    }

    func saveBatchOperation(_: @escaping () throws -> [T], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation {}
    }

    func replaceOperation(_: @escaping () throws -> [T]) -> BaseOperation<Void> { ClosureOperation {} }
    func fetchCountOperation() -> BaseOperation<Int> {
        let count = items.count
        return ClosureOperation { count }
    }

    func deleteAllOperation() -> BaseOperation<Void> { ClosureOperation {} }
}

final class CovCBPINObservable<T>: DataProviderRepositoryObservable {
    typealias Model = T

    func start(completionBlock: @escaping (Error?) -> Void) { completionBlock(nil) }
    func stop(completionBlock: @escaping (Error?) -> Void) { completionBlock(nil) }
    func addObserver(_: AnyObject, deliverOn _: DispatchQueue, executing _: @escaping ([DataProviderChange<T>]) -> Void) {}
    func removeObserver(_: AnyObject) {}
}

final class CovCBPINStakingFactory: RelaychainStakingLocalSubscriptionFactoryProtocol {
    var stashItems: [StashItem] = []
    let operationManager = OperationManager()

    func getMinNominatorBondProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedBigUInt> { throw CommonError.undefined }
    func getCounterForNominatorsProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> { throw CommonError.undefined }
    func getMaxNominatorsCountProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> { throw CommonError.undefined }
    func getNominationProvider(for _: Data, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedNomination> {
        throw CommonError.undefined
    }

    func getValidatorProvider(for _: Data, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedValidator> {
        throw CommonError.undefined
    }

    func getLedgerInfoProvider(for _: Data, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedLedgerInfo> {
        throw CommonError.undefined
    }

    func getActiveEra(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedActiveEra> { throw CommonError.undefined }
    func getCurrentEra(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedEraIndex> { throw CommonError.undefined }
    func getPayee(for _: Data, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedPayee> { throw CommonError.undefined }
    func getTotalReward(for _: AccountAddress, chain _: ChainModel, assetPrecision _: Int16) throws -> AnySingleValueProvider<TotalRewardItem> {
        throw CommonError.undefined
    }

    func getStashItemProvider(for _: AccountAddress) -> StreamableProvider<StashItem> {
        StreamableProvider(
            source: AnyStreamableSource(fearless.EmptyStreamableSource<StashItem>()),
            repository: AnyDataProviderRepository(CovCBPINRepository(items: stashItems)),
            observable: AnyDataProviderRepositoryObservable(CovCBPINObservable<StashItem>()),
            operationManager: operationManager
        )
    }

    func getPoolMembersProvider(for _: ChainAsset, accountId _: Data) throws -> AnyDataProvider<DecodedPoolMember> {
        throw CommonError.undefined
    }
}

final class CovCBPINAccountInfoAdapter: AccountInfoSubscriptionAdapterProtocol {
    var subscribedAccountIds: [Data] = []
    var resetCount = 0
    weak var lastHandler: AccountInfoSubscriptionAdapterHandler?

    func subscribe(
        chainAsset _: ChainAsset,
        accountId: Data,
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {
        subscribedAccountIds.append(accountId)
        lastHandler = handler
    }

    func subscribe(
        chainsAssets _: [ChainAsset],
        handler _: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {}

    func reset() { resetCount += 1 }
    func unsubscribe(chainAsset _: ChainAsset) {}
    func update(wallet _: fearless.MetaAccountModel) {}
}

final class CovCBPINExtrinsicService: ExtrinsicServiceProtocol {
    var submitResult: SubmitExtrinsicResult = .success("0xhash")
    var submitCount = 0

    func estimateFee(_: @escaping ExtrinsicBuilderClosure, runningIn _: DispatchQueue, completion: @escaping EstimateFeeClosure) {
        completion(.success(RuntimeDispatchInfo(feeValue: 1)))
    }

    func estimateFee(
        _: @escaping ExtrinsicBuilderIndexedClosure,
        runningIn _: DispatchQueue,
        numberOfExtrinsics _: Int,
        completion: @escaping EstimateFeeIndexedClosure
    ) {
        completion([])
    }

    func submit(
        _: @escaping ExtrinsicBuilderClosure,
        signer _: SigningWrapperProtocol,
        runningIn _: DispatchQueue,
        completion: @escaping ExtrinsicSubmitClosure
    ) {
        submitCount += 1
        completion(submitResult)
    }

    func submit(
        _: @escaping ExtrinsicBuilderIndexedClosure,
        signer _: SigningWrapperProtocol,
        runningIn _: DispatchQueue,
        numberOfExtrinsics _: Int,
        completion: @escaping ExtrinsicSubmitIndexedClosure
    ) {
        completion([])
    }

    func submitAndWatch(
        _: @escaping ExtrinsicBuilderClosure,
        signer _: SigningWrapperProtocol,
        runningIn _: DispatchQueue,
        completion: @escaping ExtrinsicSubmitAndWatchClosure
    ) {
        completion(.success("0x"), nil)
    }
}

final class CovCBPINFeeProxy: ExtrinsicFeeProxyProtocol {
    weak var delegate: ExtrinsicFeeProxyDelegate?
    var identifiers: [String] = []
    var result: Result<RuntimeDispatchInfo, Error> = .success(RuntimeDispatchInfo(feeValue: 10_000_000_000))

    func estimateFee(using _: ExtrinsicServiceProtocol, reuseIdentifier: ExtrinsicFeeId, setupBy _: @escaping ExtrinsicBuilderClosure) {
        identifiers.append(reuseIdentifier)
        delegate?.didReceiveFee(result: result, for: reuseIdentifier)
    }
}


final class CovCBPINEngine: JSONRPCEngine {
    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }

    func callMethod<P: Codable, T: Decodable>(
        _: String,
        params _: P?,
        options _: JSONRPCOptions,
        completion _: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        throw CommonError.network
    }

    func subscribe<P: Codable, T: Decodable>(
        _: String,
        params _: P?,
        updateClosure _: @escaping (T) -> Void,
        failureClosure _: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        throw CommonError.network
    }

    func cancelForIdentifier(_: UInt16) {}
    func generateRequestId() -> UInt16 { 1 }
    func addSubscription(_: JSONRPCSubscribing) {}
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_: UInt16) throws {}
}

final class CovCBPINSigner: SigningWrapperProtocol {
    func sign(_: Data) throws -> IRSignatureProtocol { throw CommonError.undefined }
}

final class CovCBPINKeystore: KeystoreProtocol {
    func addKey(_: Data, with _: String) throws {}
    func updateKey(_: Data, with _: String) throws {}
    func fetchKey(for _: String) throws -> Data { throw CommonError.undefined }
    func checkKey(for _: String) throws -> Bool { false }
    func deleteKey(for _: String) throws {}
}


final class CovCBPINRuntime: SSFRuntimeCodingService.RuntimeProviderProtocol {
    var runtimeSpecVersion: RuntimeSpecVersion = .defaultVersion
    var snapshot: RuntimeSnapshot?

    func setup() {}
    func setupHot() {}
    func cleanup() {}
    func readySnapshot() async throws -> RuntimeSnapshot { throw SSFRuntimeCodingService.RuntimeProviderError.providerUnavailable }
    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> { BaseOperation() }
    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        throw SSFRuntimeCodingService.RuntimeProviderError.providerUnavailable
    }
}

final class CovCBPINOperationFactory: ExtrinsicOperationFactoryProtocol {
    func estimateFeeOperation(
        _: @escaping ExtrinsicBuilderIndexedClosure,
        numberOfExtrinsics _: Int
    ) -> CompoundOperationWrapper<[FeeExtrinsicResult]> {
        CompoundOperationWrapper(targetOperation: ClosureOperation { [.success(RuntimeDispatchInfo(feeValue: 10_000_000_000))] })
    }

    func submit(
        _: @escaping ExtrinsicBuilderIndexedClosure,
        signer _: SigningWrapperProtocol,
        numberOfExtrinsics _: Int
    ) -> CompoundOperationWrapper<[SubmitExtrinsicResult]> {
        CompoundOperationWrapper(targetOperation: ClosureOperation { [] })
    }

    func submitAndWatch(
        _: @escaping ExtrinsicBuilderClosure,
        signer _: SigningWrapperProtocol
    ) -> CompoundOperationWrapper<SubmitAndWatchExtrinsicResult> {
        CompoundOperationWrapper(targetOperation: ClosureOperation { (result: .success("0x"), extrinsicHash: nil) })
    }

    func createGenesisBlockHashOperation() -> BaseOperation<String> { ClosureOperation { "0x00" } }
}

final class CovCBPINSubstrateFactory: SubstrateDataProviderFactoryProtocol {
    let operationManager = OperationManager()

    func createStashItemProvider(for _: String) -> StreamableProvider<StashItem> {
        StreamableProvider(
            source: AnyStreamableSource(fearless.EmptyStreamableSource<StashItem>()),
            repository: AnyDataProviderRepository(CovCBPINRepository<StashItem>(items: [])),
            observable: AnyDataProviderRepositoryObservable(CovCBPINObservable<StashItem>()),
            operationManager: operationManager
        )
    }

    func createStorageProvider(for _: String) -> StreamableProvider<ChainStorageItem> {
        StreamableProvider(
            source: AnyStreamableSource(fearless.EmptyStreamableSource<ChainStorageItem>()),
            repository: AnyDataProviderRepository(CovCBPINRepository<ChainStorageItem>(items: [])),
            observable: AnyDataProviderRepositoryObservable(CovCBPINObservable<ChainStorageItem>()),
            operationManager: operationManager
        )
    }
}

final class CovCBPINCalculatorEngine: RewardCalculatorEngineProtocol {
    var rewardAssetRate: Decimal { 1 }

    func calculateEarnings(amount: Decimal, validatorAccountId _: Data, isCompound _: Bool, period _: CalculationPeriod) throws -> Decimal {
        amount
    }

    func calculateMaxEarnings(amount: Decimal, isCompound _: Bool, period _: CalculationPeriod) -> Decimal { amount }
    func calculateAvgEarnings(amount: Decimal, isCompound _: Bool, period _: CalculationPeriod) -> Decimal { amount }
    func calculatorReturn(isCompound _: Bool, period _: CalculationPeriod, type _: RewardReturnType) -> Decimal { 0.1 }
    func maxEarningsTitle(locale _: Locale) -> String { "" }
    func avgEarningTitle(locale _: Locale) -> String { "" }
}

final class CovCBPINCalculatorService: RewardCalculatorServiceProtocol {
    var setupCount = 0

    func setup() { setupCount += 1 }
    func throttle() {}
    func fetchCalculatorOperation() -> BaseOperation<RewardCalculatorEngineProtocol> {
        ClosureOperation { CovCBPINCalculatorEngine() }
    }
}

final class CovCBPINPayoutService: PayoutRewardsServiceProtocol {
    var error: Error?
    var fetchCount = 0

    func fetchPayoutsOperationWrapper() -> CompoundOperationWrapper<PayoutsInfo> {
        fetchCount += 1
        let error = self.error
        return CompoundOperationWrapper(targetOperation: ClosureOperation {
            if let error = error { throw error }
            return PayoutsInfo(activeEra: 10, historyDepth: 84, payouts: [])
        })
    }
}

final class CovCBPINCountdownFactory: EraCountdownOperationFactoryProtocol {
    var fails = false

    func fetchCountdownOperationWrapper(
        for _: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol
    ) -> CompoundOperationWrapper<EraCountdown> {
        let fails = self.fails
        return CompoundOperationWrapper(targetOperation: ClosureOperation {
            if fails { throw CommonError.network }
            return EraCountdown(
                activeEra: 1,
                currentEra: 1,
                eraLength: 6,
                sessionLength: 600,
                activeEraStartSessionIndex: 1,
                currentSessionIndex: 1,
                currentSlot: 600,
                genesisSlot: 0,
                blockCreationTime: 6000,
                createdAtDate: Date()
            )
        })
    }
}

final class CovCBPINPayoutsPresenter: StakingRewardPayoutsInteractorOutputProtocol {
    var events: [String] = []

    func didReceive(result: Result<PayoutsInfo, PayoutRewardsServiceError>) {
        switch result {
        case .success: events.append("payouts")
        case .failure: events.append("payouts-failure")
        }
    }

    func didReceive(eraCountdownResult: Result<EraCountdown, Error>) {
        switch eraCountdownResult {
        case .success: events.append("countdown")
        case .failure: events.append("countdown-failure")
        }
    }
}

final class CovCBPINSetupPresenter: StakingRewardDestSetupInteractorOutputProtocol {
    var events: [String] = []
    var accountsCount: Int?

    private func tag<T>(_ result: Result<T, Error>, _ name: String) -> String {
        switch result {
        case .success: return name
        case .failure: return name + "-failure"
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) { events.append(tag(result, "fee")) }
    func didReceiveStashItem(result: Result<StashItem?, Error>) { events.append(tag(result, "stashItem")) }
    func didReceiveController(result: Result<fearless.ChainAccountResponse?, Error>) { events.append(tag(result, "controller")) }
    func didReceiveStash(result: Result<fearless.ChainAccountResponse?, Error>) { events.append(tag(result, "stash")) }
    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>) { events.append(tag(result, "ledger")) }
    func didReceiveRewardDestinationAccount(result: Result<RewardDestination<fearless.ChainAccountResponse>?, Error>) {
        events.append(tag(result, "destinationAccount"))
    }

    func didReceiveRewardDestinationAddress(result: Result<RewardDestination<AccountAddress>?, Error>) {
        events.append(tag(result, "destinationAddress"))
    }

    func didReceiveCalculator(result: Result<RewardCalculatorEngineProtocol?, Error>) { events.append(tag(result, "calculator")) }
    func didReceiveAccounts(result: Result<[fearless.ChainAccountResponse], Error>) {
        accountsCount = try? result.get().count
        events.append(tag(result, "accounts"))
    }

    func didReceiveNomination(result: Result<Nomination?, Error>) { events.append(tag(result, "nomination")) }
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) { events.append(tag(result, "accountInfo")) }
}

final class CovCBPINConfirmPresenter: StakingRewardDestConfirmInteractorOutputProtocol {
    var events: [String] = []

    private func tag<T>(_ result: Result<T, Error>, _ name: String) -> String {
        switch result {
        case .success: return name
        case .failure: return name + "-failure"
        }
    }

    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) { events.append(tag(result, "fee")) }
    func didReceiveStashItem(result: Result<StashItem?, Error>) { events.append(tag(result, "stashItem")) }
    func didReceiveController(result: Result<fearless.ChainAccountResponse?, Error>) { events.append(tag(result, "controller")) }
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) { events.append(tag(result, "accountInfo")) }
    func didSubmitRewardDest(result: Result<String, Error>) { events.append(tag(result, "submitted")) }
}

final class CovCBPINPayoutOutput: StakingPayoutConfirmationrelaychainStrategyOutput {
    var events: [String] = []
    var destinations: [RewardDestination<DisplayAddress>?] = []

    func didRecieve(account _: fearless.ChainAccountResponse, rewardAmount: Decimal) { events.append("reward-\(rewardAmount)") }
    func didReceiveAccountInfo(result _: Result<AccountInfo?, Error>, chainAsset _: ChainAsset) { events.append("accountInfo") }
    func didReceiveRewardDestination(result: Result<RewardDestination<DisplayAddress>?, Error>) {
        if case let .success(destination) = result {
            destinations.append(destination)
            events.append("destination")
        } else {
            events.append("destination-failure")
        }
    }

    func didReceiveFee(result: Result<Decimal, Error>) {
        if case let .success(fee) = result {
            events.append("fee-\(fee)")
        } else {
            events.append("fee-failure")
        }
    }

    func didStartPayout() { events.append("start") }
    func didCompletePayout(txHashes: [String]) { events.append("complete-\(txHashes.joined())") }
    func didFailPayout(error _: Error) { events.append("fail") }
}

final class CovCBPInteractorsTests: XCTestCase {
    private let wallet = AccountGenerator.generateMetaAccount()
    private let utilityAsset = AssetModel(
        id: "dot",
        name: "DOT",
        symbol: "dot",
        precision: 10,
        icon: nil,
        currencyId: nil,
        existentialDeposit: nil,
        color: nil,
        isUtility: true,
        isNative: true,
        staking: nil,
        purchaseProviders: nil,
        type: nil,
        ethereumType: nil,
        priceProvider: nil,
        coingeckoPriceId: nil
    )

    private lazy var chain: ChainModel = {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: 0)
        chain.assets = [utilityAsset]
        return chain
    }()

    private var chainAsset: ChainAsset { ChainAsset(chain: chain, asset: utilityAsset) }
    private var callFactory: SubstrateCallFactoryDefault { SubstrateCallFactoryDefault(runtimeService: CovCBPINRuntime()) }

    private func account() throws -> fearless.ChainAccountResponse {
        try XCTUnwrap(wallet.fetch(for: chain.accountRequest()))
    }

    private func walletStash() throws -> StashItem {
        let address = try XCTUnwrap(try account().toAddress())
        return StashItem(stash: address, controller: address)
    }

    private func repository() -> AnyDataProviderRepository<fearless.MetaAccountModel> {
        AnyDataProviderRepository(CovCBPINRepository(items: [wallet]))
    }

    private func waitFor(_ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    // MARK: - StakingRewardPayoutsInteractor

    private func makePayoutsInteractor(
        chain: ChainModel,
        service: CovCBPINPayoutService,
        countdown: CovCBPINCountdownFactory
    ) -> StakingRewardPayoutsInteractor {
        StakingRewardPayoutsInteractor(
            stakingLocalSubscriptionFactory: CovCBPINStakingFactory(),
            payoutService: service,
            chainAsset: ChainAsset(chain: chain, asset: utilityAsset),
            eraCountdownOperationFactory: countdown,
            operationManager: OperationManager(),
            runtimeService: CovCBPINRuntime(),
            logger: nil,
            connection: CovCBPINEngine()
        )
    }

    func testPayoutsInteractorWithoutStakingApiReturnsEmptyPayouts() {
        let presenter = CovCBPINPayoutsPresenter()
        let service = CovCBPINPayoutService()
        let interactor = makePayoutsInteractor(chain: chain, service: service, countdown: CovCBPINCountdownFactory())
        interactor.presenter = presenter

        interactor.setup()
        XCTAssertEqual(presenter.events.first, "payouts")
        waitFor { presenter.events.contains("countdown") }

        XCTAssertEqual(presenter.events, ["payouts", "countdown"])
        XCTAssertEqual(service.fetchCount, 0)
    }

    func testPayoutsInteractorWithStakingApiFetchesAndMapsErrors() {
        let base = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let stakingApi = ChainModel.BlockExplorer(type: "subquery", url: URL(fileURLWithPath: "/covcbp-staking"))
        let stakingChain = ChainModel(
            rank: nil,
            disabled: false,
            chainId: base.chainId,
            parentId: nil,
            paraId: nil,
            name: base.name,
            xcm: nil,
            nodes: base.nodes,
            addressPrefix: base.addressPrefix,
            types: nil,
            icon: nil,
            options: nil,
            externalApi: ChainModel.ExternalApiSet(staking: stakingApi, history: nil, crowdloans: nil, explorers: nil, pricing: nil),
            selectedNode: nil,
            customNodes: nil,
            iosMinAppVersion: nil,
            identityChain: nil
        )
        XCTAssertNotNil(stakingChain.externalApi?.staking)
        let presenter = CovCBPINPayoutsPresenter()
        let service = CovCBPINPayoutService()
        let countdown = CovCBPINCountdownFactory()
        countdown.fails = true
        let interactor = makePayoutsInteractor(chain: stakingChain, service: service, countdown: countdown)
        interactor.presenter = presenter

        interactor.reload()
        interactor.reload()
        XCTAssertEqual(service.fetchCount, 1)
        waitFor { presenter.events.contains("payouts") }

        service.error = PayoutRewardsServiceError.unknown
        interactor.reload()
        waitFor { presenter.events.contains("payouts-failure") }

        service.error = CommonError.network
        interactor.handleActiveEra(result: .success(nil), chainId: stakingChain.chainId)
        waitFor { presenter.events.filter { $0 == "payouts-failure" }.count == 2 && presenter.events.contains("countdown-failure") }
        interactor.handleActiveEra(result: .failure(CommonError.undefined), chainId: stakingChain.chainId)

        XCTAssertEqual(service.fetchCount, 3)
        XCTAssertEqual(presenter.events.filter { $0 == "payouts-failure" }.count, 2)
        XCTAssertTrue(presenter.events.contains("countdown-failure"))
    }

    // MARK: - StakingRewardDestSetupInteractor

    private func makeSetupInteractor(
        factory: CovCBPINStakingFactory = CovCBPINStakingFactory(),
        adapter: CovCBPINAccountInfoAdapter = CovCBPINAccountInfoAdapter(),
        feeProxy: CovCBPINFeeProxy = CovCBPINFeeProxy(),
        calculator: CovCBPINCalculatorService = CovCBPINCalculatorService()
    ) -> StakingRewardDestSetupInteractor {
        StakingRewardDestSetupInteractor(
            accountRepository: repository(),
            stakingLocalSubscriptionFactory: factory,
            accountInfoSubscriptionAdapter: adapter,
            substrateProviderFactory: CovCBPINSubstrateFactory(),
            calculatorService: calculator,
            runtimeService: CovCBPINRuntime(),
            operationManager: OperationManager(),
            feeProxy: feeProxy,
            chainAsset: chainAsset,
            selectedAccount: wallet,
            connection: CovCBPINEngine(),
            callFactory: callFactory
        )
    }

    func testDestSetupInteractorSetupLoadsStashAndCalculator() throws {
        let factory = CovCBPINStakingFactory()
        factory.stashItems = [try walletStash()]
        let adapter = CovCBPINAccountInfoAdapter()
        let feeProxy = CovCBPINFeeProxy()
        let calculator = CovCBPINCalculatorService()
        let presenter = CovCBPINSetupPresenter()
        let interactor = makeSetupInteractor(factory: factory, adapter: adapter, feeProxy: feeProxy, calculator: calculator)
        interactor.presenter = presenter

        interactor.setup()
        XCTAssertEqual(calculator.setupCount, 1)
        XCTAssertTrue(feeProxy.delegate === interactor)
        waitFor { ["calculator", "stash", "controller"].allSatisfy(presenter.events.contains) }

        XCTAssertTrue(presenter.events.contains("stashItem"))
        XCTAssertTrue(presenter.events.contains("calculator"))
        XCTAssertEqual(adapter.resetCount, 1)
        XCTAssertEqual(adapter.subscribedAccountIds, [try account().accountId])
        XCTAssertNotNil(interactor.extrinsicService)
    }

    func testDestSetupInteractorHandlersWithoutStash() {
        let presenter = CovCBPINSetupPresenter()
        let interactor = makeSetupInteractor()
        interactor.presenter = presenter

        interactor.estimateFee(rewardDestination: .restake)
        interactor.handleStashItem(result: .success(nil), for: "address")
        XCTAssertEqual(presenter.events, ["stashItem", "ledger", "accountInfo", "destinationAccount", "nomination", "controller"])

        presenter.events.removeAll()
        interactor.handleStashItem(result: .failure(CommonError.undefined), for: "address")
        XCTAssertEqual(presenter.events, [
            "stashItem-failure", "controller-failure", "ledger-failure", "accountInfo-failure",
            "destinationAccount-failure", "nomination-failure"
        ])

        presenter.events.removeAll()
        interactor.handlePayee(result: .success(.staked), accountId: Data(), chainId: chain.chainId)
        interactor.handleLedgerInfo(result: .success(nil), accountId: Data(), chainId: chain.chainId)
        interactor.handleNomination(result: .success(nil), accountId: Data(), chainId: chain.chainId)
        interactor.handleAccountInfo(result: .success(nil), accountId: Data(), chainAsset: chainAsset)
        interactor.didReceiveFee(result: .success(RuntimeDispatchInfo(feeValue: 1)), for: "id")
        XCTAssertEqual(presenter.events, ["destinationAccount-failure", "ledger", "nomination", "accountInfo", "fee"])
    }

    func testDestSetupInteractorPayeeFeeAndAccounts() throws {
        let presenter = CovCBPINSetupPresenter()
        let feeProxy = CovCBPINFeeProxy()
        let interactor = makeSetupInteractor(feeProxy: feeProxy)
        interactor.presenter = presenter
        interactor.extrinsicService = CovCBPINExtrinsicService()
        feeProxy.delegate = interactor

        interactor.handleStashItem(result: .success(try walletStash()), for: "address")
        waitFor { presenter.events.contains("stash") && presenter.events.contains("controller") }
        presenter.events.removeAll()

        interactor.handlePayee(result: .success(.staked), accountId: Data(), chainId: chain.chainId)
        XCTAssertEqual(presenter.events, ["fee", "destinationAccount"])

        presenter.events.removeAll()
        interactor.handlePayee(result: .success(.account(try account().accountId)), accountId: Data(), chainId: chain.chainId)
        waitFor { presenter.events.contains("destinationAccount") }
        XCTAssertEqual(presenter.events, ["fee", "destinationAccount"])

        presenter.events.removeAll()
        interactor.handlePayee(result: .success(.account(Data(repeating: 9, count: 32))), accountId: Data(), chainId: chain.chainId)
        waitFor { presenter.events.contains("destinationAddress") }
        XCTAssertEqual(presenter.events, ["fee", "destinationAddress"])

        presenter.events.removeAll()
        interactor.handlePayee(result: .failure(CommonError.undefined), accountId: Data(), chainId: chain.chainId)
        interactor.estimateFee(rewardDestination: .payout(account: "invalid"))
        XCTAssertEqual(presenter.events, ["destinationAccount-failure", "fee-failure"])

        interactor.fetchPayoutAccounts()
        waitFor { presenter.events.contains("accounts") }
        XCTAssertEqual(presenter.accountsCount, 1)
        XCTAssertEqual(feeProxy.identifiers.count, 3)
    }
}

final class CovCBPInteractorsConfirmTests: XCTestCase {
    private let wallet = AccountGenerator.generateMetaAccount()
    private let utilityAsset = AssetModel(
        id: "dot", name: "DOT", symbol: "dot", precision: 10, icon: nil, currencyId: nil, existentialDeposit: nil, color: nil,
        isUtility: true, isNative: true, staking: nil, purchaseProviders: nil, type: nil, ethereumType: nil, priceProvider: nil,
        coingeckoPriceId: nil
    )

    private lazy var chain: ChainModel = {
        let chain = ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: 0)
        chain.assets = [utilityAsset]
        return chain
    }()

    private var chainAsset: ChainAsset { ChainAsset(chain: chain, asset: utilityAsset) }

    private func account() throws -> fearless.ChainAccountResponse {
        try XCTUnwrap(wallet.fetch(for: chain.accountRequest()))
    }

    private func walletStash() throws -> StashItem {
        let address = try XCTUnwrap(try account().toAddress())
        return StashItem(stash: address, controller: address)
    }

    private func waitFor(_ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }

    private func makeConfirmInteractor(
        factory: CovCBPINStakingFactory,
        service: CovCBPINExtrinsicService,
        feeProxy: CovCBPINFeeProxy
    ) -> StakingRewardDestConfirmInteractor {
        StakingRewardDestConfirmInteractor(
            stakingLocalSubscriptionFactory: factory,
            accountInfoSubscriptionAdapter: CovCBPINAccountInfoAdapter(),
            extrinsicService: service,
            substrateProviderFactory: CovCBPINSubstrateFactory(),
            runtimeService: CovCBPINRuntime(),
            operationManager: OperationManager(),
            feeProxy: feeProxy,
            chainAsset: chainAsset,
            selectedAccount: wallet,
            signingWrapper: CovCBPINSigner(),
            connection: CovCBPINEngine(),
            keystore: CovCBPINKeystore(),
            accountRepository: AnyDataProviderRepository(CovCBPINRepository(items: [wallet])),
            callFactory: SubstrateCallFactoryDefault(runtimeService: CovCBPINRuntime())
        )
    }

    // MARK: - StakingRewardDestConfirmInteractor

    func testDestConfirmInteractorSetupLoadsController() throws {
        let factory = CovCBPINStakingFactory()
        factory.stashItems = [try walletStash()]
        let feeProxy = CovCBPINFeeProxy()
        let presenter = CovCBPINConfirmPresenter()
        let interactor = makeConfirmInteractor(factory: factory, service: CovCBPINExtrinsicService(), feeProxy: feeProxy)
        interactor.presenter = presenter

        interactor.setup()
        XCTAssertTrue(feeProxy.delegate === interactor)
        waitFor { presenter.events.contains("controller") }

        XCTAssertEqual(presenter.events, ["stashItem", "controller"])
        XCTAssertTrue(interactor.extrinsicService is ExtrinsicService)
    }

    func testDestConfirmInteractorFeeSubmitAndStashHandling() throws {
        let service = CovCBPINExtrinsicService()
        let feeProxy = CovCBPINFeeProxy()
        let presenter = CovCBPINConfirmPresenter()
        let interactor = makeConfirmInteractor(factory: CovCBPINStakingFactory(), service: service, feeProxy: feeProxy)
        interactor.presenter = presenter
        feeProxy.delegate = interactor
        let stash = try walletStash()

        interactor.estimateFee(for: .restake, stashItem: stash)
        interactor.estimateFee(for: .payout(account: "invalid"), stashItem: stash)
        interactor.submit(rewardDestination: .payout(account: stash.stash), for: stash)
        service.submitResult = .failure(CommonError.network)
        interactor.submit(rewardDestination: .restake, for: stash)
        interactor.submit(rewardDestination: .payout(account: "invalid"), for: stash)
        XCTAssertEqual(presenter.events, ["fee", "fee-failure", "submitted", "submitted-failure", "submitted-failure"])
        XCTAssertEqual(service.submitCount, 2)

        presenter.events.removeAll()
        interactor.handleStashItem(result: .success(nil), for: "address")
        interactor.handleStashItem(result: .failure(CommonError.undefined), for: "address")
        interactor.handleStashItem(result: .success(StashItem(stash: "bad", controller: "bad")), for: "address")
        interactor.handleAccountInfo(result: .success(nil), accountId: Data(), chainAsset: chainAsset)
        XCTAssertEqual(presenter.events, [
            "stashItem", "accountInfo", "controller",
            "stashItem-failure", "controller", "accountInfo-failure",
            "stashItem-failure", "controller", "accountInfo-failure",
            "accountInfo"
        ])
    }

    // MARK: - StakingPayoutConfirmationRelayachainStrategy

    private func makePayoutStrategy(
        payouts: [PayoutInfo],
        chain: ChainModel? = nil,
        factory: CovCBPINStakingFactory = CovCBPINStakingFactory(),
        adapter: CovCBPINAccountInfoAdapter = CovCBPINAccountInfoAdapter(),
        service: CovCBPINExtrinsicService = CovCBPINExtrinsicService(),
        output: CovCBPINPayoutOutput
    ) -> StakingPayoutConfirmationRelayachainStrategy {
        StakingPayoutConfirmationRelayachainStrategy(
            stakingLocalSubscriptionFactory: factory,
            accountInfoSubscriptionAdapter: adapter,
            extrinsicService: service,
            extrinsicOperationFactory: CovCBPINOperationFactory(),
            runtimeService: CovCBPINRuntime(),
            signer: CovCBPINSigner(),
            operationManager: OperationManager(),
            logger: nil,
            wallet: wallet,
            payouts: payouts,
            chainAsset: ChainAsset(chain: chain ?? self.chain, asset: utilityAsset),
            accountRepository: AnyDataProviderRepository(CovCBPINRepository(items: [wallet])),
            output: output,
            callFactory: SubstrateCallFactoryDefault(runtimeService: CovCBPINRuntime())
        )
    }

    private var payouts: [PayoutInfo] {
        [
            PayoutInfo(era: 1, validator: Data(repeating: 1, count: 32), reward: 1.5, identity: nil),
            PayoutInfo(era: 2, validator: Data(repeating: 2, count: 32), reward: 0.5, identity: nil)
        ]
    }

    func testPayoutStrategySetupEstimatesFeeAndReward() throws {
        let factory = CovCBPINStakingFactory()
        factory.stashItems = [try walletStash()]
        let adapter = CovCBPINAccountInfoAdapter()
        let output = CovCBPINPayoutOutput()
        let strategy = makePayoutStrategy(payouts: payouts, factory: factory, adapter: adapter, output: output)

        strategy.setup()
        XCTAssertTrue(output.events.contains("reward-2"))
        XCTAssertEqual(adapter.subscribedAccountIds, [try account().accountId])
        waitFor { output.events.contains("fee-1") }

        XCTAssertTrue(output.events.contains("fee-1"))
        XCTAssertFalse(output.events.contains("destination-failure"))
    }

    func testPayoutStrategyFeeFailsWithoutUtilityAssetOrPayouts() {
        let bareChain = ChainModelGenerator.generateChain(generatingAssets: 0, addressPrefix: 0)
        let output = CovCBPINPayoutOutput()
        let service = CovCBPINExtrinsicService()

        makePayoutStrategy(payouts: payouts, chain: bareChain, output: output).estimateFee(builderClosure: nil)
        let empty = makePayoutStrategy(payouts: [], service: service, output: output)
        empty.estimateFee(builderClosure: nil)
        empty.submitPayout(builderClosure: nil)

        XCTAssertEqual(output.events, ["fee-failure", "fee-failure"])
        XCTAssertEqual(service.submitCount, 0)
    }

    func testPayoutStrategySubmitAndRewardDestination() throws {
        let output = CovCBPINPayoutOutput()
        let service = CovCBPINExtrinsicService()
        let strategy = makePayoutStrategy(payouts: payouts, service: service, output: output)
        let chainId = chain.chainId

        strategy.submitPayout(builderClosure: nil)
        service.submitResult = .failure(CommonError.network)
        strategy.submitPayout(builderClosure: nil)
        XCTAssertEqual(output.events, ["start", "complete-0xhash", "start", "fail"])

        output.events.removeAll()
        strategy.handlePayee(result: .success(.staked), accountId: Data(), chainId: chainId)
        strategy.handleStashItem(result: .success(nil), for: "address")
        strategy.handleStashItem(result: .success(try walletStash()), for: "address")
        strategy.handlePayee(result: .success(.staked), accountId: Data(), chainId: chainId)
        strategy.handlePayee(result: .success(nil), accountId: Data(), chainId: chainId)
        strategy.handlePayee(result: .failure(CommonError.undefined), accountId: Data(), chainId: chainId)
        strategy.handleStashItem(result: .failure(CommonError.undefined), for: "address")
        strategy.handleAccountInfo(result: .success(nil), accountId: Data(), chainAsset: chainAsset)
        XCTAssertEqual(output.events, [
            "destination-failure", "destination", "destination", "destination-failure", "destination-failure", "accountInfo"
        ])
        XCTAssertNil(output.destinations[0])
        guard case .restake = output.destinations[1] else { return XCTFail("restake expected") }

        strategy.handleStashItem(result: .success(try walletStash()), for: "address")
        output.events.removeAll()
        strategy.handlePayee(result: .success(.stash), accountId: Data(), chainId: chainId)
        waitFor { output.events.contains("destination") }

        guard case let .payout(displayAddress) = output.destinations.last else { return XCTFail("payout expected") }
        XCTAssertEqual(displayAddress.username, wallet.name)
        XCTAssertEqual(displayAddress.address, try walletStash().stash)
    }
}
