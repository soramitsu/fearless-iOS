import XCTest
import SSFModels
import BigInt
import RobinHood
import IrohaCrypto
import SSFUtils
import SSFRuntimeCodingService
@testable import fearless

enum CovCABCAIError: Error {
    case failed
}

final class CovCABCAIRuntime: RuntimeProviderProtocol {
    var snapshot: RuntimeSnapshot? { nil }
    var runtimeSpecVersion: RuntimeSpecVersion { .defaultVersion }

    func setup() {}
    func cleanup() {}
    func setupHot() {}

    func readySnapshot() async throws -> RuntimeSnapshot {
        throw CovCABCAIError.failed
    }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        let operation = BaseOperation<RuntimeCoderFactoryProtocol>()
        operation.result = .failure(CovCABCAIError.failed)
        return operation
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        throw CovCABCAIError.failed
    }
}

final class CovCABCAIEngine: JSONRPCEngine {
    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }

    func callMethod<P: Codable, T: Decodable>(
        _: String,
        params _: P?,
        options _: JSONRPCOptions,
        completion _: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        throw CovCABCAIError.failed
    }

    func subscribe<P: Codable, T: Decodable>(
        _: String,
        params _: P?,
        updateClosure _: @escaping (T) -> Void,
        failureClosure _: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        throw CovCABCAIError.failed
    }

    func cancelForIdentifier(_: UInt16) {}
    func generateRequestId() -> UInt16 { 1 }
    func addSubscription(_: JSONRPCSubscribing) {}
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_: UInt16) throws {}
}

final class CovCABCAIAdapter: AccountInfoSubscriptionAdapterProtocol {
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

final class CovCABCAIStakingFactory: RelaychainStakingLocalSubscriptionFactoryProtocol {
    func getMinNominatorBondProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedBigUInt> { throw CovCABCAIError.failed }
    func getCounterForNominatorsProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> { throw CovCABCAIError.failed }
    func getMaxNominatorsCountProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> { throw CovCABCAIError.failed }

    func getNominationProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedNomination> {
        throw CovCABCAIError.failed
    }

    func getValidatorProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedValidator> {
        throw CovCABCAIError.failed
    }

    func getLedgerInfoProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedLedgerInfo> {
        throw CovCABCAIError.failed
    }

    func getActiveEra(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedActiveEra> { throw CovCABCAIError.failed }
    func getCurrentEra(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedEraIndex> { throw CovCABCAIError.failed }

    func getPayee(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedPayee> {
        throw CovCABCAIError.failed
    }

    func getTotalReward(for _: AccountAddress, chain _: ChainModel, assetPrecision _: Int16) throws -> AnySingleValueProvider<TotalRewardItem> {
        throw CovCABCAIError.failed
    }

    func getStashItemProvider(for address: AccountAddress) -> StreamableProvider<StashItem> {
        SubstrateDataProviderFactory(facade: SubstrateDataStorageFacade.shared, operationManager: OperationManager())
            .createStashItemProvider(for: address)
    }

    func getPoolMembersProvider(for _: ChainAsset, accountId _: AccountId) throws -> AnyDataProvider<DecodedPoolMember> {
        throw CovCABCAIError.failed
    }
}

final class CovCABCAIRepository: DataProviderRepositoryProtocol {
    typealias Model = fearless.MetaAccountModel

    let models: [fearless.MetaAccountModel]

    init(models: [fearless.MetaAccountModel]) {
        self.models = models
    }

    private func failing<T>() -> BaseOperation<T> {
        let operation = BaseOperation<T>()
        operation.result = .failure(CovCABCAIError.failed)
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

final class CovCABCAIExtrinsicService: ExtrinsicServiceProtocol {
    var feeResult: Result<RuntimeDispatchInfo, Error> = .success(RuntimeDispatchInfo(feeValue: BigUInt(1000)))
    var submitResult: Result<String, Error> = .success("0xhash")
    private(set) var estimateCalls = 0
    private(set) var submitCalls = 0

    func estimateFee(_: @escaping ExtrinsicBuilderClosure, runningIn _: DispatchQueue, completion completionClosure: @escaping EstimateFeeClosure) {
        estimateCalls += 1
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
        submitCalls += 1
        completionClosure(submitResult)
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
        completionClosure(submitResult, nil)
    }
}

final class CovCABCAISigner: SigningWrapperProtocol {
    func sign(_: Data) throws -> IRSignatureProtocol {
        throw CovCABCAIError.failed
    }
}

final class CovCABCAIOutput: ControllerAccountInteractorOutputProtocol {
    private(set) var stashItems: [Result<StashItem?, Error>] = []
    private(set) var stashAccounts: [Result<fearless.ChainAccountResponse?, Error>] = []
    private(set) var controllerAccounts: [Result<fearless.ChainAccountResponse?, Error>] = []
    private(set) var accounts: [Result<[fearless.ChainAccountResponse], Error>] = []
    private(set) var fees: [Result<RuntimeDispatchInfo, Error>] = []
    private(set) var accountInfos: [(result: Result<AccountInfo?, Error>, address: AccountAddress)] = []
    private(set) var ledgers: [Result<StakingLedger?, Error>] = []

    func didReceiveStashItem(result: Result<StashItem?, Error>) { stashItems.append(result) }
    func didReceiveStashAccount(result: Result<fearless.ChainAccountResponse?, Error>) { stashAccounts.append(result) }
    func didReceiveControllerAccount(result: Result<fearless.ChainAccountResponse?, Error>) { controllerAccounts.append(result) }
    func didReceiveAccounts(result: Result<[fearless.ChainAccountResponse], Error>) { accounts.append(result) }
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) { fees.append(result) }
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>, address: AccountAddress) { accountInfos.append((result, address)) }
    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>) { ledgers.append(result) }
}

enum CovCABCAIFixtures {
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

    static func spin(until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
}

final class CovCABControllerAccountInteractorTests: XCTestCase {
    private var output: CovCABCAIOutput!
    private var adapter: CovCABCAIAdapter!
    private var service: CovCABCAIExtrinsicService!
    private var feeProxy: ExtrinsicFeeProxy!
    private var interactor: ControllerAccountInteractor!
    private var chain: ChainModel!
    private var repoWallet: fearless.MetaAccountModel!

    override func setUp() {
        super.setUp()
        chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        repoWallet = AccountGenerator.generateMetaAccount()
        output = CovCABCAIOutput()
        adapter = CovCABCAIAdapter()
        service = CovCABCAIExtrinsicService()
        feeProxy = ExtrinsicFeeProxy()
        let runtime = CovCABCAIRuntime()
        let operationManager = OperationManager()
        interactor = ControllerAccountInteractor(
            accountInfoSubscriptionAdapter: adapter,
            stakingLocalSubscriptionFactory: CovCABCAIStakingFactory(),
            runtimeService: runtime,
            accountRepository: AnyDataProviderRepository(CovCABCAIRepository(models: [repoWallet])),
            operationManager: operationManager,
            feeProxy: feeProxy,
            extrinsicService: service,
            storageRequestFactory: StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: operationManager),
            engine: CovCABCAIEngine(),
            chainAsset: ChainAsset(chain: chain, asset: asset),
            selectedAccount: CovCABCAIFixtures.walletWithoutSubstrate(),
            callFactory: SubstrateCallFactoryDefault(runtimeService: runtime)
        )
        interactor.presenter = output
    }

    override func tearDown() {
        interactor = nil
        feeProxy = nil
        service = nil
        adapter = nil
        output = nil
        chain = nil
        repoWallet = nil
        super.tearDown()
    }

    private func repoAccount() throws -> fearless.ChainAccountResponse {
        try XCTUnwrap(repoWallet.fetch(for: chain.accountRequest()))
    }

    func testSetupFetchesAccountsAndBecomesFeeDelegate() throws {
        interactor.setup()
        CovCABCAIFixtures.spin { !output.accounts.isEmpty }

        XCTAssertTrue(feeProxy.delegate === interactor)
        let accounts = try XCTUnwrap(try output.accounts.first?.get())
        XCTAssertEqual(accounts, [try repoAccount()])
    }

    func testEstimateFeeDeliversResultThroughProxy() throws {
        feeProxy.delegate = interactor
        interactor.estimateFee(for: try repoAccount())

        XCTAssertEqual(service.estimateCalls, 1)
        XCTAssertEqual(output.fees.count, 1)
        XCTAssertEqual(try output.fees.first?.get().fee, "1000")

        interactor.didReceiveFee(result: .failure(CovCABCAIError.failed), for: "id")
        XCTAssertEqual(output.fees.count, 2)
    }

    func testFetchWithInvalidAddressFailsImmediately() {
        interactor.fetchControllerAccountInfo(controllerAddress: "not-an-address")
        interactor.fetchLedger(controllerAddress: "not-an-address")

        XCTAssertEqual(output.accountInfos.count, 1)
        XCTAssertEqual(output.accountInfos.first?.address, "not-an-address")
        XCTAssertThrowsError(try output.accountInfos.first?.result.get())
        XCTAssertEqual(output.ledgers.count, 1)
        XCTAssertThrowsError(try output.ledgers.first?.get())
    }

    func testFetchWithValidAddressReportsRuntimeFailure() throws {
        let address = try XCTUnwrap(try repoAccount().toAddress())

        interactor.fetchControllerAccountInfo(controllerAddress: address)
        interactor.fetchLedger(controllerAddress: address)
        CovCABCAIFixtures.spin { !output.accountInfos.isEmpty && !output.ledgers.isEmpty }

        XCTAssertEqual(output.accountInfos.first?.address, address)
        XCTAssertThrowsError(try output.accountInfos.first?.result.get())
        XCTAssertThrowsError(try output.ledgers.first?.get())
    }

    func testSubscriptionHandlersForwardResults() throws {
        let account = try repoAccount()
        let data = AccountData(free: 5, reserved: 0, frozen: 0, flags: 0)
        let info = AccountInfo(nonce: 0, consumers: 0, providers: 0, data: data)

        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        interactor.handleAccountInfo(result: .success(info), accountId: account.accountId, chainAsset: ChainAsset(chain: chain, asset: asset))
        XCTAssertEqual(output.accountInfos.first?.address, account.toAddress())

        interactor.handleLedgerInfo(result: .success(nil), accountId: account.accountId, chainId: chain.chainId)
        XCTAssertEqual(output.ledgers.count, 1)

        interactor.handleStashItem(result: .failure(CovCABCAIError.failed), for: "stash")
        interactor.handleStashItem(result: .success(nil), for: "stash")
        XCTAssertEqual(output.stashItems.count, 2)
        XCTAssertThrowsError(try output.stashItems[0].get())
        XCTAssertNil(try output.stashItems[1].get())
        XCTAssertTrue(adapter.subscribedAccountIds.isEmpty)
    }

    func testStashItemFetchesStashAndControllerAccounts() throws {
        feeProxy.delegate = interactor
        let foreign = try XCTUnwrap(AccountGenerator.generateMetaAccount().fetch(for: chain.accountRequest()))
        let stashAddress = try XCTUnwrap(foreign.toAddress())
        let controllerAddress = try XCTUnwrap(try repoAccount().toAddress())

        interactor.handleStashItem(result: .success(StashItem(stash: stashAddress, controller: controllerAddress)), for: stashAddress)
        CovCABCAIFixtures.spin { !output.stashAccounts.isEmpty && !output.controllerAccounts.isEmpty }

        XCTAssertEqual(adapter.subscribedAccountIds, [foreign.accountId])
        XCTAssertThrowsError(try output.stashAccounts.first?.get())
        XCTAssertEqual(try output.controllerAccounts.first?.get(), try repoAccount())
        XCTAssertEqual(output.fees.count, 1)
    }
}

final class CovCABCACIOutput: ControllerAccountConfirmationInteractorOutputProtocol {
    private(set) var stashItems: [Result<StashItem?, Error>] = []
    private(set) var stashAccounts: [Result<fearless.ChainAccountResponse?, Error>] = []
    private(set) var fees: [Result<RuntimeDispatchInfo, Error>] = []
    private(set) var ledgers: [Result<StakingLedger?, Error>] = []
    private(set) var accountInfos: [Result<AccountInfo?, Error>] = []
    private(set) var confirmations: [Result<String, Error>] = []

    func didReceiveStashItem(result: Result<StashItem?, Error>) { stashItems.append(result) }
    func didReceiveStashAccount(result: Result<fearless.ChainAccountResponse?, Error>) { stashAccounts.append(result) }
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) { fees.append(result) }
    func didReceiveStakingLedger(result: Result<StakingLedger?, Error>) { ledgers.append(result) }
    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) { accountInfos.append(result) }
    func didConfirmed(result: Result<String, Error>) { confirmations.append(result) }
}

final class CovCABControllerAccountConfirmationInteractorTests: XCTestCase {
    private var output: CovCABCACIOutput!
    private var service: CovCABCAIExtrinsicService!
    private var feeProxy: ExtrinsicFeeProxy!
    private var interactor: ControllerAccountConfirmationInteractor!
    private var chain: ChainModel!
    private var repoWallet: fearless.MetaAccountModel!

    override func setUp() {
        super.setUp()
        chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        repoWallet = AccountGenerator.generateMetaAccount()
        output = CovCABCACIOutput()
        service = CovCABCAIExtrinsicService()
        feeProxy = ExtrinsicFeeProxy()
        let runtime = CovCABCAIRuntime()
        let operationManager = OperationManager()
        let controller = AccountGenerator.generateMetaAccount().fetch(for: chain.accountRequest())
        interactor = ControllerAccountConfirmationInteractor(
            accountInfoSubscriptionAdapter: CovCABCAIAdapter(),
            stakingLocalSubscriptionFactory: CovCABCAIStakingFactory(),
            runtimeService: runtime,
            extrinsicService: service,
            signingWrapper: CovCABCAISigner(),
            feeProxy: feeProxy,
            controllerAccountItem: controller ?? fearless.ChainAccountResponse(
                chainId: chain.chainId,
                accountId: Data(repeating: 1, count: 32),
                publicKey: Data(repeating: 1, count: 32),
                name: "fallback",
                cryptoType: .sr25519,
                addressPrefix: 0,
                isEthereumBased: false,
                isChainAccount: false,
                walletId: "w"
            ),
            accountRepository: AnyDataProviderRepository(CovCABCAIRepository(models: [repoWallet])),
            operationManager: operationManager,
            storageRequestFactory: StorageRequestFactory(remoteFactory: StorageKeyFactory(), operationManager: operationManager),
            engine: CovCABCAIEngine(),
            chainAsset: ChainAsset(chain: chain, asset: asset),
            selectedAccount: CovCABCAIFixtures.walletWithoutSubstrate(),
            callFactory: SubstrateCallFactoryDefault(runtimeService: runtime)
        )
        interactor.presenter = output
    }

    override func tearDown() {
        interactor = nil
        feeProxy = nil
        service = nil
        output = nil
        chain = nil
        repoWallet = nil
        super.tearDown()
    }

    func testSetupEstimatesFeeAndCachedFeeReachesPresenter() {
        interactor.setup()

        XCTAssertEqual(service.estimateCalls, 1)
        XCTAssertTrue(feeProxy.delegate === interactor)
        XCTAssertTrue(output.fees.isEmpty)

        interactor.estimateFee()
        XCTAssertEqual(service.estimateCalls, 1)
        XCTAssertEqual(output.fees.count, 1)
        XCTAssertEqual(try output.fees.first?.get().fee, "1000")
    }

    func testConfirmSubmitsAndReportsResult() {
        interactor.confirm()
        service.submitResult = .failure(CovCABCAIError.failed)
        interactor.confirm()

        XCTAssertEqual(service.submitCalls, 2)
        XCTAssertEqual(output.confirmations.count, 2)
        XCTAssertEqual(try output.confirmations.first?.get(), "0xhash")
        XCTAssertThrowsError(try output.confirmations.last?.get())
    }

    func testFetchStashAccountItemFindsRepositoryAccount() throws {
        let address = try XCTUnwrap(repoWallet.fetch(for: chain.accountRequest())?.toAddress())

        interactor.fetchStashAccountItem(for: address)
        CovCABCAIFixtures.spin { !output.stashAccounts.isEmpty }

        XCTAssertEqual(try output.stashAccounts.first?.get()?.toAddress(), address)
    }

    func testFetchLedgerReportsRuntimeFailure() {
        interactor.fetchLedger()
        CovCABCAIFixtures.spin { !output.ledgers.isEmpty }

        XCTAssertEqual(output.ledgers.count, 1)
        XCTAssertThrowsError(try output.ledgers.first?.get())
    }

    func testHandlersForwardResults() throws {
        let info = AccountInfo(nonce: 0, consumers: 0, providers: 0, data: AccountData(free: 1, reserved: 0, frozen: 0, flags: 0))
        let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
        interactor.handleAccountInfo(result: .success(info), accountId: Data(repeating: 2, count: 32), chainAsset: ChainAsset(chain: chain, asset: asset))
        XCTAssertEqual(try output.accountInfos.first?.get(), info)

        interactor.didReceiveFee(result: .failure(CovCABCAIError.failed), for: "id")
        XCTAssertEqual(output.fees.count, 1)

        interactor.handleStashItem(result: .failure(CovCABCAIError.failed), for: "stash")
        interactor.handleStashItem(result: .success(nil), for: "stash")
        XCTAssertEqual(output.stashItems.count, 2)
    }

    func testStashItemWithUnknownStashReportsMissingAccount() throws {
        let foreign = try XCTUnwrap(AccountGenerator.generateMetaAccount().fetch(for: chain.accountRequest())?.toAddress())

        interactor.handleStashItem(result: .success(StashItem(stash: foreign, controller: foreign)), for: foreign)
        CovCABCAIFixtures.spin { !output.stashAccounts.isEmpty }

        XCTAssertEqual(output.stashItems.count, 1)
        XCTAssertThrowsError(try output.stashAccounts.first?.get())
    }
}
