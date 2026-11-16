import XCTest
import BigInt
import RobinHood
import IrohaCrypto
import SoraKeystore
import SSFModels
import SSFUtils
import SSFRuntimeCodingService
@testable import fearless

final class CovCBPSTRepository<T: Identifiable>: DataProviderRepositoryProtocol {
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

final class CovCBPSTObservable<T>: DataProviderRepositoryObservable {
    typealias Model = T

    func start(completionBlock: @escaping (Error?) -> Void) { completionBlock(nil) }
    func stop(completionBlock: @escaping (Error?) -> Void) { completionBlock(nil) }
    func addObserver(_: AnyObject, deliverOn _: DispatchQueue, executing _: @escaping ([DataProviderChange<T>]) -> Void) {}
    func removeObserver(_: AnyObject) {}
}

final class CovCBPSTStakingFactory: RelaychainStakingLocalSubscriptionFactoryProtocol {
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
            repository: AnyDataProviderRepository(CovCBPSTRepository(items: stashItems)),
            observable: AnyDataProviderRepositoryObservable(CovCBPSTObservable<StashItem>()),
            operationManager: operationManager
        )
    }

    func getPoolMembersProvider(for _: ChainAsset, accountId _: Data) throws -> AnyDataProvider<DecodedPoolMember> {
        throw CommonError.undefined
    }
}

final class CovCBPSTAccountInfoAdapter: AccountInfoSubscriptionAdapterProtocol {
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

final class CovCBPSTExtrinsicService: ExtrinsicServiceProtocol {
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

final class CovCBPSTFeeProxy: ExtrinsicFeeProxyProtocol {
    weak var delegate: ExtrinsicFeeProxyDelegate?
    var identifiers: [String] = []
    var result: Result<RuntimeDispatchInfo, Error> = .success(RuntimeDispatchInfo(feeValue: 10_000_000_000))

    func estimateFee(using _: ExtrinsicServiceProtocol, reuseIdentifier: ExtrinsicFeeId, setupBy _: @escaping ExtrinsicBuilderClosure) {
        identifiers.append(reuseIdentifier)
        delegate?.didReceiveFee(result: result, for: reuseIdentifier)
    }
}

final class CovCBPSTEDService: ExistentialDepositServiceProtocol {
    func fetchExistentialDeposit(chainAsset _: ChainAsset, completion: @escaping (Result<BigUInt, Error>) -> Void) {
        completion(.success(10_000_000_000))
    }
}

final class CovCBPSTEngine: JSONRPCEngine {
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

final class CovCBPSTSigner: SigningWrapperProtocol {
    func sign(_: Data) throws -> IRSignatureProtocol { throw CommonError.undefined }
}

final class CovCBPSTKeystore: KeystoreProtocol {
    func addKey(_: Data, with _: String) throws {}
    func updateKey(_: Data, with _: String) throws {}
    func fetchKey(for _: String) throws -> Data { throw CommonError.undefined }
    func checkKey(for _: String) throws -> Bool { false }
    func deleteKey(for _: String) throws {}
}

final class CovCBPSTEventCenter: EventCenterProtocol {
    var notified = 0

    func notify(with _: EventProtocol) { notified += 1 }
    func add(observer _: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {}
    func remove(observer _: EventVisitorProtocol) {}
}

final class CovCBPSTRuntime: SSFRuntimeCodingService.RuntimeProviderProtocol {
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

final class CovCBPSTOperationFactory: ExtrinsicOperationFactoryProtocol {
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

final class CovCBPSTOutput: StakingBondMorePoolStrategyOutput, StakingBondMoreRelaychainStrategyOutput,
    StakingBondMoreConfirmationPoolStrategyOutput, StakingBondMoreConfirmationRelaychainStrategyOutput,
    StakingPayoutConfirmationPoolStrategyOutput {
    var events: [String] = []

    private func tag<T>(_ result: Result<T, Error>, _ name: String) -> String {
        switch result {
        case .success: return name
        case .failure: return name + "-failure"
        }
    }

    func didReceiveAccountInfo(result: Result<AccountInfo?, Error>) { events.append(tag(result, "account")) }
    func didReceiveFee(result: Result<RuntimeDispatchInfo, Error>) { events.append(tag(result, "fee")) }
    func didReceiveExistentialDeposit(result _: Result<BigUInt, Error>) { events.append("ed") }
    func extrinsicServiceUpdated() { events.append("serviceUpdated") }
    func didReceiveStash(result: Result<fearless.ChainAccountResponse?, Error>) {
        events.append(((try? result.get()) ?? nil) != nil ? "stash" : "stash-none")
    }

    func didReceiveStashItem(result: Result<StashItem?, Error>) { events.append(tag(result, "stashItem")) }
    func didSubmitBonding(result: Result<String, Error>) { events.append(tag(result, "submitted")) }
    func didRecieve(account _: fearless.ChainAccountResponse, rewardAmount: Decimal) { events.append("reward-\(rewardAmount)") }
    func didStartPayout() { events.append("start") }
    func didCompletePayout(result: SubmitExtrinsicResult) { events.append(tag(result, "payout")) }
    func didFailPayout(error _: Error) { events.append("payout-error") }
}

final class CovCBPStrategiesTests: XCTestCase {
    private let chain = ChainModelGenerator.generateChain(generatingAssets: 1, addressPrefix: 0)
    private let asset = ChainModelGenerator.generateAssetWithId("dot", symbol: "DOT", assetPresicion: 10)
    private let wallet = AccountGenerator.generateMetaAccount()

    private var chainAsset: ChainAsset { ChainAsset(chain: chain, asset: asset) }
    private var callFactory: SubstrateCallFactoryDefault { SubstrateCallFactoryDefault(runtimeService: CovCBPSTRuntime()) }

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

    private func repository() -> AnyDataProviderRepository<fearless.MetaAccountModel> {
        AnyDataProviderRepository(CovCBPSTRepository(items: [wallet]))
    }

    func testBondMorePoolStrategy() throws {
        let output = CovCBPSTOutput()
        let adapter = CovCBPSTAccountInfoAdapter()
        let feeProxy = CovCBPSTFeeProxy()
        let strategy = StakingBondMorePoolStrategy(
            accountInfoSubscriptionAdapter: adapter,
            output: output,
            chainAsset: chainAsset,
            wallet: wallet,
            connection: CovCBPSTEngine(),
            extrinsicService: CovCBPSTExtrinsicService(),
            feeProxy: feeProxy,
            runtimeService: CovCBPSTRuntime(),
            operationManager: OperationManager(),
            callFactory: callFactory,
            existentialDepositService: CovCBPSTEDService()
        )
        XCTAssertTrue(feeProxy.delegate === strategy)

        strategy.setup()
        XCTAssertEqual(adapter.subscribedAccountIds, [try account().accountId])
        XCTAssertTrue(adapter.lastHandler === strategy)

        strategy.estimateFee(builderClosure: nil, reuseIdentifier: "id")
        strategy.estimateFee(builderClosure: { $0 }, reuseIdentifier: "id")
        strategy.handleAccountInfo(result: .success(nil), accountId: Data(), chainAsset: chainAsset)

        XCTAssertEqual(feeProxy.identifiers, ["id"])
        XCTAssertEqual(output.events, ["ed", "fee", "account"])
    }

    func testBondMoreRelaychainStrategySetupLoadsStash() throws {
        let output = CovCBPSTOutput()
        let adapter = CovCBPSTAccountInfoAdapter()
        let factory = CovCBPSTStakingFactory()
        factory.stashItems = [try walletStash()]
        let strategy = StakingBondMoreRelaychainStrategy(
            stakingLocalSubscriptionFactory: factory,
            accountInfoSubscriptionAdapter: adapter,
            output: output,
            chainAsset: chainAsset,
            wallet: wallet,
            accountRepository: repository(),
            connection: CovCBPSTEngine(),
            extrinsicService: CovCBPSTExtrinsicService(),
            feeProxy: CovCBPSTFeeProxy(),
            runtimeService: CovCBPSTRuntime(),
            operationManager: OperationManager(),
            callFactory: callFactory,
            existentialDepositService: CovCBPSTEDService()
        )

        strategy.setup()
        waitFor { output.events.contains("stash") }

        XCTAssertEqual(output.events, ["ed", "stashItem", "serviceUpdated", "stash"])
        XCTAssertEqual(adapter.resetCount, 1)
        XCTAssertEqual(adapter.subscribedAccountIds, [try account().accountId])
    }

    func testBondMoreRelaychainStrategyHandlesMissingStash() {
        let output = CovCBPSTOutput()
        let adapter = CovCBPSTAccountInfoAdapter()
        let feeProxy = CovCBPSTFeeProxy()
        feeProxy.result = .failure(CommonError.network)
        let strategy = StakingBondMoreRelaychainStrategy(
            stakingLocalSubscriptionFactory: CovCBPSTStakingFactory(),
            accountInfoSubscriptionAdapter: adapter,
            output: output,
            chainAsset: chainAsset,
            wallet: wallet,
            accountRepository: repository(),
            connection: CovCBPSTEngine(),
            extrinsicService: CovCBPSTExtrinsicService(),
            feeProxy: feeProxy,
            runtimeService: CovCBPSTRuntime(),
            operationManager: OperationManager(),
            callFactory: callFactory,
            existentialDepositService: CovCBPSTEDService()
        )

        strategy.handleStashItem(result: .success(nil), for: "address")
        strategy.handleStashItem(result: .failure(CommonError.undefined), for: "address")
        strategy.estimateFee(builderClosure: { $0 }, reuseIdentifier: nil)
        strategy.estimateFee(builderClosure: { $0 }, reuseIdentifier: "fee")
        strategy.handleAccountInfo(result: .failure(CommonError.undefined), accountId: Data(), chainAsset: chainAsset)

        XCTAssertEqual(output.events, ["stashItem", "account", "stashItem-failure", "account-failure", "fee-failure", "account-failure"])
        XCTAssertEqual(adapter.resetCount, 1)
    }

    func testBondMoreConfirmationPoolStrategy() throws {
        let output = CovCBPSTOutput()
        let adapter = CovCBPSTAccountInfoAdapter()
        let feeProxy = CovCBPSTFeeProxy()
        let service = CovCBPSTExtrinsicService()
        let eventCenter = CovCBPSTEventCenter()
        let strategy = StakingBondMoreConfirmationPoolStrategy(
            accountInfoSubscriptionAdapter: adapter,
            chainAsset: chainAsset,
            wallet: wallet,
            extrinsicService: service,
            feeProxy: feeProxy,
            runtimeService: CovCBPSTRuntime(),
            operationManager: OperationManager(),
            connection: CovCBPSTEngine(),
            keystore: CovCBPSTKeystore(),
            signingWrapper: CovCBPSTSigner(),
            output: output,
            eventCenter: eventCenter,
            logger: Logger.shared,
            callFactory: callFactory
        )

        strategy.setup()
        XCTAssertTrue(feeProxy.delegate === strategy)
        XCTAssertEqual(adapter.subscribedAccountIds, [try account().accountId])

        strategy.estimateFee(builderClosure: nil, reuseIdentifier: "id")
        strategy.estimateFee(builderClosure: { $0 }, reuseIdentifier: nil)
        strategy.estimateFee(builderClosure: { $0 }, reuseIdentifier: "id")
        strategy.submit(builderClosure: nil)
        strategy.submit(builderClosure: { $0 })
        strategy.handleAccountInfo(result: .success(nil), accountId: Data(), chainAsset: chainAsset)

        XCTAssertEqual(output.events, ["fee", "submitted", "account"])
        XCTAssertEqual(service.submitCount, 1)
        XCTAssertEqual(eventCenter.notified, 1)
    }

    private func makeConfirmRelayStrategy(
        output: CovCBPSTOutput,
        adapter: CovCBPSTAccountInfoAdapter,
        factory: CovCBPSTStakingFactory,
        service: CovCBPSTExtrinsicService,
        feeProxy: CovCBPSTFeeProxy
    ) -> StakingBondMoreConfirmationRelaychainStrategy {
        StakingBondMoreConfirmationRelaychainStrategy(
            stakingLocalSubscriptionFactory: factory,
            accountInfoSubscriptionAdapter: adapter,
            chainAsset: chainAsset,
            wallet: wallet,
            extrinsicService: service,
            feeProxy: feeProxy,
            runtimeService: CovCBPSTRuntime(),
            operationManager: OperationManager(),
            accountRepository: repository(),
            connection: CovCBPSTEngine(),
            keystore: CovCBPSTKeystore(),
            signingWrapper: CovCBPSTSigner(),
            output: output,
            callFactory: callFactory
        )
    }

    func testBondMoreConfirmationRelaychainStrategySetup() throws {
        let output = CovCBPSTOutput()
        let adapter = CovCBPSTAccountInfoAdapter()
        let factory = CovCBPSTStakingFactory()
        factory.stashItems = [try walletStash()]
        let feeProxy = CovCBPSTFeeProxy()
        let strategy = makeConfirmRelayStrategy(
            output: output,
            adapter: adapter,
            factory: factory,
            service: CovCBPSTExtrinsicService(),
            feeProxy: feeProxy
        )

        strategy.setup()
        XCTAssertTrue(feeProxy.delegate === strategy)
        waitFor { output.events.contains("stash") }

        XCTAssertEqual(output.events, ["stashItem", "stash"])
        XCTAssertEqual(adapter.resetCount, 1)
        XCTAssertEqual(adapter.subscribedAccountIds, [try account().accountId])
    }

    func testBondMoreConfirmationRelaychainStrategyActions() {
        let output = CovCBPSTOutput()
        let service = CovCBPSTExtrinsicService()
        service.submitResult = .failure(CommonError.network)
        let feeProxy = CovCBPSTFeeProxy()
        let strategy = makeConfirmRelayStrategy(
            output: output,
            adapter: CovCBPSTAccountInfoAdapter(),
            factory: CovCBPSTStakingFactory(),
            service: service,
            feeProxy: feeProxy
        )
        feeProxy.delegate = strategy

        strategy.estimateFee(builderClosure: nil, reuseIdentifier: "id")
        strategy.estimateFee(builderClosure: { $0 }, reuseIdentifier: "id")
        strategy.submit(builderClosure: nil)
        strategy.submit(builderClosure: { $0 })
        strategy.handleStashItem(result: .success(nil), for: "address")
        strategy.handleStashItem(result: .failure(CommonError.undefined), for: "address")
        strategy.handleAccountInfo(result: .success(nil), accountId: Data(), chainAsset: chainAsset)

        XCTAssertEqual(output.events, [
            "fee", "submitted-failure", "stashItem", "account", "stashItem-failure", "account-failure", "account"
        ])
        XCTAssertEqual(service.submitCount, 1)
    }

    func testPayoutPoolStrategy() throws {
        let output = CovCBPSTOutput()
        let adapter = CovCBPSTAccountInfoAdapter()
        let feeProxy = CovCBPSTFeeProxy()
        let service = CovCBPSTExtrinsicService()
        let strategy = StakingPayoutConfirmationPoolStrategy(
            rewardAmount: 3,
            stakingLocalSubscriptionFactory: CovCBPSTStakingFactory(),
            accountInfoSubscriptionAdapter: adapter,
            extrinsicService: service,
            extrinsicOperationFactory: CovCBPSTOperationFactory(),
            runtimeService: CovCBPSTRuntime(),
            signer: CovCBPSTSigner(),
            operationManager: OperationManager(),
            logger: nil,
            wallet: wallet,
            chainAsset: chainAsset,
            output: output,
            feeProxy: feeProxy
        )

        strategy.setup()
        XCTAssertTrue(feeProxy.delegate === strategy)
        XCTAssertEqual(adapter.subscribedAccountIds, [try account().accountId])

        strategy.estimateFee(builderClosure: nil)
        strategy.estimateFee(builderClosure: { $0 })
        strategy.submitPayout(builderClosure: nil)
        strategy.submitPayout(builderClosure: { $0 })
        service.submitResult = .failure(CommonError.network)
        strategy.submitPayout(builderClosure: { $0 })
        strategy.handleAccountInfo(result: .success(nil), accountId: Data(), chainAsset: chainAsset)

        XCTAssertEqual(output.events, ["reward-3", "fee", "start", "payout", "start", "payout-failure", "account"])
        XCTAssertEqual(feeProxy.identifiers, [""])
    }
}
