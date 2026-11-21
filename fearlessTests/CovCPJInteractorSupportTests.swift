import XCTest
import RobinHood
import SSFModels
import SSFRuntimeCodingService
import IrohaCrypto
import BigInt
@testable import fearless

// Immediate-answer doubles for the CovCPJ interactor tests.

final class CovCPJIntOperationManager: OperationManagerProtocol {
    private let queue = OperationQueue()
    private(set) var enqueuedCount = 0

    func enqueue(operations: [Operation], in _: OperationMode) {
        enqueuedCount += operations.count
        queue.addOperations(operations, waitUntilFinished: false)
    }
}

enum CovCPJIntWrappers {
    static func wrapper<T>(_ result: Result<T, Error>) -> CompoundOperationWrapper<T> {
        let operation = BaseOperation<T>()
        operation.result = result
        return CompoundOperationWrapper(targetOperation: operation)
    }
}

final class CovCPJIntPoolOperationFactory: StakingPoolOperationFactoryProtocol {
    var bondedPools: Result<[StakingPool], Error> = .success([])
    var minJoinBond: BigUInt?
    var minCreateBond: BigUInt?
    var poolMember: StakingPoolMember?
    var maxPoolsCount: UInt32?
    var maxPoolMembers: UInt32?
    var bondedPoolsCounter: UInt32?
    var maxMembersPerPool: UInt32?
    var lastPoolId: UInt32?
    private(set) var memberRequests: [AccountId] = []

    func fetchBondedPoolsOperation() -> CompoundOperationWrapper<[StakingPool]> {
        CovCPJIntWrappers.wrapper(bondedPools)
    }

    func fetchPoolMetadataOperation(poolId _: String) -> CompoundOperationWrapper<String?> {
        CovCPJIntWrappers.wrapper(.success(nil))
    }

    func fetchMinJoinBondOperation() -> CompoundOperationWrapper<BigUInt?> {
        CovCPJIntWrappers.wrapper(.success(minJoinBond))
    }

    func fetchMinCreateBondOperation() -> CompoundOperationWrapper<BigUInt?> {
        CovCPJIntWrappers.wrapper(.success(minCreateBond))
    }

    func fetchStakingPoolMembers(accountId: AccountId) -> CompoundOperationWrapper<StakingPoolMember?> {
        memberRequests.append(accountId)
        return CovCPJIntWrappers.wrapper(.success(poolMember))
    }

    func fetchMaxStakingPoolsCount() -> CompoundOperationWrapper<UInt32?> {
        CovCPJIntWrappers.wrapper(.success(maxPoolsCount))
    }

    func fetchMaxPoolMembers() -> CompoundOperationWrapper<UInt32?> {
        CovCPJIntWrappers.wrapper(.success(maxPoolMembers))
    }

    func fetchCounterForBondedPools() -> CompoundOperationWrapper<UInt32?> {
        CovCPJIntWrappers.wrapper(.success(bondedPoolsCounter))
    }

    func fetchMaxPoolMembersPerPool() -> CompoundOperationWrapper<UInt32?> {
        CovCPJIntWrappers.wrapper(.success(maxMembersPerPool))
    }

    func fetchBondedPoolOperation(poolId _: String) -> CompoundOperationWrapper<StakingPool?> {
        CovCPJIntWrappers.wrapper(.success(nil))
    }

    func fetchPoolRewardsOperation(poolId _: String) -> CompoundOperationWrapper<StakingPoolRewards?> {
        CovCPJIntWrappers.wrapper(.success(nil))
    }

    func fetchLastPoolId() -> CompoundOperationWrapper<UInt32?> {
        CovCPJIntWrappers.wrapper(.success(lastPoolId))
    }

    func fetchPendingRewards(accountId _: AccountId) -> CompoundOperationWrapper<BigUInt?> {
        CovCPJIntWrappers.wrapper(.success(nil))
    }
}

final class CovCPJIntFeeProxy: ExtrinsicFeeProxyProtocol {
    weak var delegate: ExtrinsicFeeProxyDelegate?
    private(set) var reuseIdentifiers: [ExtrinsicFeeId] = []

    func estimateFee(
        using _: ExtrinsicServiceProtocol,
        reuseIdentifier: ExtrinsicFeeId,
        setupBy _: @escaping ExtrinsicBuilderClosure
    ) {
        reuseIdentifiers.append(reuseIdentifier)
    }
}

final class CovCPJIntExtrinsicService: ExtrinsicServiceProtocol {
    var submitResult: SubmitExtrinsicResult = .success("0xfeed")
    private(set) var submitCount = 0

    func estimateFee(
        _: @escaping ExtrinsicBuilderClosure,
        runningIn _: DispatchQueue,
        completion completionClosure: @escaping EstimateFeeClosure
    ) {
        completionClosure(.failure(CovCPJTestError.failed))
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
        submitCount += 1
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

final class CovCPJIntAccountAdapter: AccountInfoSubscriptionAdapterProtocol {
    var accountInfo: AccountInfo?
    private(set) var subscribedAccountIds: [AccountId] = []

    func subscribe(
        chainAsset: ChainAsset,
        accountId: AccountId,
        handler: AccountInfoSubscriptionAdapterHandler?,
        deliveryOn _: DispatchQueue?,
        notifyJustWhenUpdated _: Bool
    ) {
        subscribedAccountIds.append(accountId)
        handler?.handleAccountInfo(result: .success(accountInfo), accountId: accountId, chainAsset: chainAsset)
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

final class CovCPJIntDepositService: ExistentialDepositServiceProtocol {
    var result: Result<BigUInt, Error> = .success(BigUInt(10_000_000_000))

    func fetchExistentialDeposit(chainAsset _: ChainAsset, completion: @escaping (Result<BigUInt, Error>) -> Void) {
        completion(result)
    }
}

/// Runtime provider without metadata: every coder-factory request fails at once.
final class CovCPJIntRuntimeProvider: RuntimeProviderProtocol {
    var snapshot: RuntimeSnapshot? { nil }
    var runtimeSpecVersion: RuntimeSpecVersion { .defaultVersion }

    func setup() {}
    func readySnapshot() async throws -> RuntimeSnapshot { throw CovCPJTestError.failed }
    func cleanup() {}
    func setupHot() {}

    func fetchCoderFactoryOperation() -> BaseOperation<RuntimeCoderFactoryProtocol> {
        let operation = BaseOperation<RuntimeCoderFactoryProtocol>()
        operation.result = .failure(CovCPJTestError.failed)
        return operation
    }

    func fetchCoderFactory() async throws -> RuntimeCoderFactoryProtocol {
        throw CovCPJTestError.failed
    }
}

final class CovCPJIntSigner: NSObject, SigningWrapperProtocol {
    func sign(_: Data) throws -> IRSignatureProtocol {
        throw CovCPJTestError.failed
    }
}

/// Thread-safe event log for outputs that are called from operation queues.
final class CovCPJIntEventLog {
    private let lock = NSLock()
    private var storage: [String] = []

    var events: [String] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    func append(_ event: String) {
        lock.lock()
        storage.append(event)
        lock.unlock()
    }

    func contains(_ event: String) -> Bool {
        events.contains(event)
    }
}

final class CovCPJInteractorSupportTests: XCTestCase {
    func testWrapperCarriesPresetResult() throws {
        let wrapper = CovCPJIntWrappers.wrapper(.success(5))
        let manager = CovCPJIntOperationManager()
        var value: Int?

        wrapper.targetOperation.completionBlock = {
            DispatchQueue.main.async {
                if case let .success(result) = wrapper.targetOperation.result {
                    value = result
                }
            }
        }
        manager.enqueue(operations: wrapper.allOperations, in: .transient)
        CovCPJFixtures.spin { value != nil }

        XCTAssertEqual(value, 5)
        XCTAssertEqual(manager.enqueuedCount, 1)
    }
}
