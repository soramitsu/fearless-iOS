import XCTest
import BigInt
import RobinHood
import SoraKeystore
import SSFModels
import SSFUtils
import SSFRuntimeCodingService
@testable import fearless

// Hand-written collaborators for the staking flow strategies. Nothing here touches the network or the keychain.

enum CovCUBOperations {
    static func wrapper<T>(_ value: T) -> CompoundOperationWrapper<T> {
        CompoundOperationWrapper(targetOperation: ClosureOperation { value })
    }

    /// Spins the main run loop until `condition` holds or two seconds pass.
    static func wait(until condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(2)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        }
    }
}

/// Records enqueued operations without running them.
final class CovCUBOperationRecorder: OperationManagerProtocol {
    private(set) var enqueued: [Operation] = []

    func enqueue(operations: [Operation], in _: OperationMode) {
        enqueued.append(contentsOf: operations)
    }
}

final class CovCUBRepositoryStub<T: Identifiable>: DataProviderRepositoryProtocol {
    typealias Model = T

    var models: [T]

    init(models: [T] = []) {
        self.models = models
    }

    func fetchOperation(by _: @escaping () throws -> [String], options _: RepositoryFetchOptions) -> BaseOperation<[T]> {
        let models = self.models
        return ClosureOperation { models }
    }

    func fetchOperation(by modelIdClosure: @escaping () throws -> String, options _: RepositoryFetchOptions) -> BaseOperation<T?> {
        let models = self.models
        return ClosureOperation {
            let identifier = try modelIdClosure()
            return models.first { $0.identifier == identifier }
        }
    }

    func fetchAllOperation(with _: RepositoryFetchOptions) -> BaseOperation<[T]> {
        let models = self.models
        return ClosureOperation { models }
    }

    func fetchOperation(by _: RepositorySliceRequest, options _: RepositoryFetchOptions) -> BaseOperation<[T]> {
        let models = self.models
        return ClosureOperation { models }
    }

    func saveOperation(_: @escaping () throws -> [T], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation {}
    }

    func saveBatchOperation(_: @escaping () throws -> [T], _: @escaping () throws -> [String]) -> BaseOperation<Void> {
        ClosureOperation {}
    }

    func replaceOperation(_: @escaping () throws -> [T]) -> BaseOperation<Void> {
        ClosureOperation {}
    }

    func fetchCountOperation() -> BaseOperation<Int> {
        let count = models.count
        return ClosureOperation { count }
    }

    func deleteAllOperation() -> BaseOperation<Void> {
        ClosureOperation {}
    }
}

final class CovCUBObservableStub<T>: DataProviderRepositoryObservable {
    typealias Model = T

    func start(completionBlock: @escaping (Error?) -> Void) { completionBlock(nil) }
    func stop(completionBlock: @escaping (Error?) -> Void) { completionBlock(nil) }
    func addObserver(_: AnyObject, deliverOn _: DispatchQueue, executing _: @escaping ([DataProviderChange<T>]) -> Void) {}
    func removeObserver(_: AnyObject) {}
}

final class CovCUBStreamableSourceStub<T: Identifiable>: StreamableSourceProtocol {
    typealias Model = T

    func fetchHistory(runningIn _: DispatchQueue?, commitNotificationBlock _: ((Result<Int, Error>?) -> Void)?) {}
    func refresh(runningIn _: DispatchQueue?, commitNotificationBlock _: ((Result<Int, Error>?) -> Void)?) {}
}

/// Every storage-backed provider is unavailable (the subscriber then keeps no provider); stash items come from an
/// inert in-memory stream.
final class CovCUBStakingSubscriptionFactoryStub: RelaychainStakingLocalSubscriptionFactoryProtocol {
    private(set) var stashRequests: [AccountAddress] = []
    let recorder = CovCUBOperationRecorder()

    func getMinNominatorBondProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedBigUInt> {
        throw CovCUBTestError.failed
    }

    func getCounterForNominatorsProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> {
        throw CovCUBTestError.failed
    }

    func getMaxNominatorsCountProvider(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedU32> {
        throw CovCUBTestError.failed
    }

    func getNominationProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedNomination> {
        throw CovCUBTestError.failed
    }

    func getValidatorProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedValidator> {
        throw CovCUBTestError.failed
    }

    func getLedgerInfoProvider(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedLedgerInfo> {
        throw CovCUBTestError.failed
    }

    func getActiveEra(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedActiveEra> {
        throw CovCUBTestError.failed
    }

    func getCurrentEra(for _: ChainModel.Id) throws -> AnyDataProvider<DecodedEraIndex> {
        throw CovCUBTestError.failed
    }

    func getPayee(for _: AccountId, chainAsset _: ChainAsset) throws -> AnyDataProvider<DecodedPayee> {
        throw CovCUBTestError.failed
    }

    func getTotalReward(
        for _: AccountAddress,
        chain _: ChainModel,
        assetPrecision _: Int16
    ) throws -> AnySingleValueProvider<TotalRewardItem> {
        throw CovCUBTestError.failed
    }

    func getStashItemProvider(for address: AccountAddress) -> StreamableProvider<StashItem> {
        stashRequests.append(address)
        return StreamableProvider(
            source: AnyStreamableSource(CovCUBStreamableSourceStub<StashItem>()),
            repository: AnyDataProviderRepository(CovCUBRepositoryStub<StashItem>()),
            observable: AnyDataProviderRepositoryObservable(CovCUBObservableStub<StashItem>()),
            operationManager: recorder
        )
    }

    func getPoolMembersProvider(for _: ChainAsset, accountId _: AccountId) throws -> AnyDataProvider<DecodedPoolMember> {
        throw CovCUBTestError.failed
    }
}

final class CovCUBAccountInfoAdapterSpy: AccountInfoSubscriptionAdapterProtocol {
    private(set) var subscribedAccounts: [AccountId] = []
    private(set) var resets = 0

    func subscribe(
        chainAsset _: ChainAsset,
        accountId: AccountId,
        handler _: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {
        subscribedAccounts.append(accountId)
    }

    func subscribe(
        chainsAssets _: [ChainAsset],
        handler _: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {}

    func reset() { resets += 1 }
    func unsubscribe(chainAsset _: ChainAsset) {}
    func update(wallet _: fearless.MetaAccountModel) {}
}

/// A runtime whose coder factory is never available.
final class CovCUBRuntimeStub: RuntimeCodingServiceProtocol {
    var snapshot: RuntimeSnapshot? { nil }

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        ClosureOperation { throw CovCUBTestError.failed }
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        throw CovCUBTestError.failed
    }
}

final class CovCUBEngineStub: JSONRPCEngine {
    var connectionName: String?
    var url: URL?
    var pendingEngineRequests: [JSONRPCRequest] { [] }

    func callMethod<P: Codable, T: Decodable>(
        _: String,
        params _: P?,
        options _: JSONRPCOptions,
        completion _: ((Result<T, Error>) -> Void)?
    ) throws -> UInt16 {
        throw CovCUBTestError.failed
    }

    func subscribe<P: Codable, T: Decodable>(
        _: String,
        params _: P?,
        updateClosure _: @escaping (T) -> Void,
        failureClosure _: @escaping (Error, Bool) -> Void
    ) throws -> UInt16 {
        throw CovCUBTestError.failed
    }

    func cancelForIdentifier(_: UInt16) {}
    func generateRequestId() -> UInt16 { 1 }
    func addSubscription(_: JSONRPCSubscribing) {}
    func reconnect(url _: URL) {}
    func connectIfNeeded() {}
    func disconnectIfNeeded() {}
    func unsubsribe(_: UInt16) throws {}
}

final class CovCUBFeeProxySpy: ExtrinsicFeeProxyProtocol {
    weak var delegate: ExtrinsicFeeProxyDelegate?
    private(set) var reuseIdentifiers: [ExtrinsicFeeId] = []
    private(set) var closures: [ExtrinsicBuilderClosure] = []

    func estimateFee(
        using _: ExtrinsicServiceProtocol,
        reuseIdentifier: ExtrinsicFeeId,
        setupBy closure: @escaping ExtrinsicBuilderClosure
    ) {
        reuseIdentifiers.append(reuseIdentifier)
        closures.append(closure)
    }
}

final class CovCUBExtrinsicServiceStub: ExtrinsicServiceProtocol {
    var submitResult: SubmitExtrinsicResult = .success("0xsubmitted")
    private(set) var submissions = 0

    func estimateFee(
        _: @escaping ExtrinsicBuilderClosure,
        runningIn _: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeClosure
    ) {
        completionClosure(.failure(CovCUBTestError.failed))
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
        submissions += 1
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
        completionClosure(.failure(CovCUBTestError.failed), nil)
    }
}

final class CovCUBKeystoreStub: KeystoreProtocol {
    func addKey(_: Data, with _: String) throws {}
    func updateKey(_: Data, with _: String) throws {}
    func fetchKey(for _: String) throws -> Data { throw CovCUBTestError.failed }
    func checkKey(for _: String) throws -> Bool { false }
    func deleteKey(for _: String) throws {}
}

final class CovCUBEventCenterSpy: EventCenterProtocol {
    private(set) var events: [EventProtocol] = []

    func notify(with event: EventProtocol) { events.append(event) }
    func add(observer _: EventVisitorProtocol, dispatchIn _: DispatchQueue?) {}
    func remove(observer _: EventVisitorProtocol) {}
}

final class CovCUBSlashesFactoryStub: SlashesOperationFactoryProtocol {
    var spans: SlashingSpans?
    private(set) var stashes: [AccountAddress] = []

    func createSlashingSpansOperationForStash(
        _ stashAddress: AccountAddress,
        engine _: JSONRPCEngine,
        runtimeService _: RuntimeCodingServiceProtocol,
        chainAsset _: ChainAsset
    ) -> CompoundOperationWrapper<SlashingSpans?> {
        stashes.append(stashAddress)
        return CovCUBOperations.wrapper(spans)
    }
}

final class CovCUBDurationFactoryStub: StakingDurationOperationFactoryProtocol {
    func createDurationOperation(from _: RuntimeCodingServiceProtocol) -> CompoundOperationWrapper<StakingDuration> {
        CovCUBOperations.wrapper(StakingDuration(session: 3600, era: 86400, unlocking: 7 * 86400))
    }
}

final class CovCUBPoolOperationFactoryStub: StakingPoolOperationFactoryProtocol {
    var bondedPool: StakingPool?
    private(set) var requestedPoolIds: [String] = []

    func fetchBondedPoolsOperation() -> CompoundOperationWrapper<[StakingPool]> { CovCUBOperations.wrapper([]) }
    func fetchPoolMetadataOperation(poolId _: String) -> CompoundOperationWrapper<String?> { CovCUBOperations.wrapper(nil) }
    func fetchMinJoinBondOperation() -> CompoundOperationWrapper<BigUInt?> { CovCUBOperations.wrapper(BigUInt(10)) }
    func fetchMinCreateBondOperation() -> CompoundOperationWrapper<BigUInt?> { CovCUBOperations.wrapper(BigUInt(20)) }
    func fetchStakingPoolMembers(accountId _: AccountId) -> CompoundOperationWrapper<StakingPoolMember?> {
        CovCUBOperations.wrapper(nil)
    }

    func fetchMaxStakingPoolsCount() -> CompoundOperationWrapper<UInt32?> { CovCUBOperations.wrapper(64) }
    func fetchMaxPoolMembers() -> CompoundOperationWrapper<UInt32?> { CovCUBOperations.wrapper(1000) }
    func fetchCounterForBondedPools() -> CompoundOperationWrapper<UInt32?> { CovCUBOperations.wrapper(5) }
    func fetchMaxPoolMembersPerPool() -> CompoundOperationWrapper<UInt32?> { CovCUBOperations.wrapper(100) }

    func fetchBondedPoolOperation(poolId: String) -> CompoundOperationWrapper<StakingPool?> {
        requestedPoolIds.append(poolId)
        return CovCUBOperations.wrapper(bondedPool)
    }

    func fetchPoolRewardsOperation(poolId _: String) -> CompoundOperationWrapper<StakingPoolRewards?> {
        CovCUBOperations.wrapper(nil)
    }

    func fetchLastPoolId() -> CompoundOperationWrapper<UInt32?> { CovCUBOperations.wrapper(7) }
    func fetchPendingRewards(accountId _: AccountId) -> CompoundOperationWrapper<BigUInt?> { CovCUBOperations.wrapper(nil) }
}

/// The collaborators a strategy needs, in one place.
final class CovCUBStrategyKit {
    let subscriptions = CovCUBStakingSubscriptionFactoryStub()
    let accountInfo = CovCUBAccountInfoAdapterSpy()
    let runtime = CovCUBRuntimeStub()
    let operations = OperationManager()
    let feeProxy = CovCUBFeeProxySpy()
    let engine = CovCUBEngineStub()
    let keystore = CovCUBKeystoreStub()
    let extrinsicService = CovCUBExtrinsicServiceStub()
    let eventCenter = CovCUBEventCenterSpy()
    let slashes = CovCUBSlashesFactoryStub()
    let durations = CovCUBDurationFactoryStub()
    let pools = CovCUBPoolOperationFactoryStub()
    let callFactory = CovCUBCallFactoryStub()
    let wallet: fearless.MetaAccountModel
    let chainAsset: ChainAsset
    let walletRepository: AnyDataProviderRepository<fearless.MetaAccountModel>

    init(chainAsset: ChainAsset, wallet: fearless.MetaAccountModel) {
        self.chainAsset = chainAsset
        self.wallet = wallet
        walletRepository = AnyDataProviderRepository(CovCUBRepositoryStub<fearless.MetaAccountModel>(models: [wallet]))
    }

    func signingWrapper() throws -> SigningWrapper {
        SigningWrapper(
            keystore: keystore,
            metaId: wallet.metaId,
            accountResponse: try CovCUBFixture.account(for: chainAsset, wallet: wallet)
        )
    }
}
