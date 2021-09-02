import Foundation
import RobinHood
import BigInt
import CommonWallet

final class SubqueryRewardSource {
    typealias Model = TotalRewardItem

    struct SyncState {
        let lastId: String?
        let receivedCount: Int
        let reward: Decimal?
    }

    let address: String
    let chain: Chain
    let targetIdentifier: String
    let repository: AnyDataProviderRepository<SingleValueProviderObject>
    let operationFactory: SubqueryHistoryOperationFactoryProtocol
    let trigger: DataProviderTriggerProtocol
    let operationManager: OperationManagerProtocol
    let pageSize: Int
    let logger: LoggerProtocol?

    private var lastSyncError: Error?
    private var syncing: SyncState?
    private var totalReward: TotalRewardItem?
    private let mutex = NSLock()

    init(
        address: String,
        chain: Chain,
        targetIdentifier: String,
        repository: AnyDataProviderRepository<SingleValueProviderObject>,
        operationFactory: SubqueryHistoryOperationFactoryProtocol,
        trigger: DataProviderTriggerProtocol,
        operationManager: OperationManagerProtocol,
        pageSize: Int = 1000,
        logger: LoggerProtocol? = nil
    ) {
        self.address = address
        self.chain = chain
        self.targetIdentifier = targetIdentifier
        self.repository = repository
        self.operationFactory = operationFactory
        self.trigger = trigger
        self.operationManager = operationManager
        self.pageSize = pageSize
        self.logger = logger

        sync()
    }

    private func createLocalFetchWrapper() -> CompoundOperationWrapper<TotalRewardItem?> {
        let fetchOperation = repository.fetchOperation(by: targetIdentifier, options: RepositoryFetchOptions())

        let mapOperation = ClosureOperation<TotalRewardItem?> {
            do {
                let rawItem = try fetchOperation.extractNoCancellableResultData()

                if let payload = rawItem?.payload {
                    return try JSONDecoder().decode(TotalRewardItem.self, from: payload)
                } else {
                    return nil
                }
            } catch {
                return nil
            }
        }

        mapOperation.addDependency(fetchOperation)

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: [fetchOperation])
    }

    private func sync() {
        guard syncing == nil else {
            return
        }

        syncing = SyncState(
            lastId: nil,
            receivedCount: 0,
            reward: nil
        )

        fetch(cursor: nil)
    }

    private func fetch(cursor: String?) {
        let localWrapper = createLocalFetchWrapper()

        let remoteOperation = operationFactory.createOperation(
            address: address,
            count: pageSize,
            cursor: cursor
        )

        let syncOperation = Operation()

        localWrapper.allOperations.forEach { syncOperation.addDependency($0) }
        syncOperation.addDependency(remoteOperation)

        syncOperation.completionBlock = {
            DispatchQueue.global(qos: .userInitiated).async {
                self.mutex.lock()

                defer {
                    self.mutex.unlock()
                }

                self.processOperations(
                    localWrapper.targetOperation,
                    remoteOperation: remoteOperation,
                    cursor: cursor
                )
            }
        }

        let allOperations = localWrapper.allOperations + [remoteOperation, syncOperation]
        operationManager.enqueue(operations: allOperations, in: .transient)
    }

    private func processOperations(
        _ localOperation: BaseOperation<TotalRewardItem?>,
        remoteOperation: BaseOperation<SubqueryHistoryData>,
        cursor _: String?
    ) {
        do {
            let totalReward = try localOperation.extractNoCancellableResultData()
            let remoteData = try remoteOperation.extractNoCancellableResultData()

            let endIndex: Int?

            if let reward = totalReward {
                endIndex = remoteData.historyElements.nodes.firstIndex {
                    $0.identifier == reward.lastId
                }
            } else {
                endIndex = nil
            }

            let allRemoteItems = remoteData.historyElements.nodes
            let count = endIndex ?? allRemoteItems.count

            let newRemoteItems = Array(allRemoteItems[0 ..< count])
            let pageReward = calculateReward(from: newRemoteItems)

            let receivedCount = (syncing?.receivedCount ?? 0) + newRemoteItems.count

            syncing = SyncState(
                lastId: syncing?.lastId ?? newRemoteItems.first?.identifier,
                receivedCount: receivedCount,
                reward: (syncing?.reward ?? 0.0) + pageReward
            )

            logger?.debug("Synced id: \(String(describing: allRemoteItems.last?.identifier))")
            logger?.debug("Persistent id: \(String(describing: totalReward?.lastId))")
            logger?.debug("Page reward: \(pageReward)")

            let newCursor = remoteData.historyElements.pageInfo.endCursor

            if endIndex != nil || newCursor == nil {
                finalize(with: totalReward)
            } else {
                fetch(cursor: newCursor)
            }

        } catch {
            finalize(with: error)
        }
    }

    private func finalize(with previousReward: TotalRewardItem?) {
        guard let syncState = syncing else {
            logger?.warning("Can't finalize sync because of nil")
            return
        }

        if let lastId = syncState.lastId, let reward = syncState.reward {
            let newAmount = reward + (previousReward?.amount.decimalValue ?? 0.0)
            totalReward = TotalRewardItem(
                address: address,
                lastId: lastId,
                amount: AmountDecimal(value: newAmount)
            )

            syncing = nil

            logger?.debug("Did receive new reward: \(reward)")
        } else {
            logger?.debug("Sync completed: nothing changed")

            totalReward = TotalRewardItem(
                address: address,
                lastId: previousReward?.lastId ?? "",
                amount: previousReward?.amount ?? AmountDecimal(value: 0.0)
            )

            syncing = nil
        }

        DispatchQueue.global().async {
            self.trigger.delegate?.didTrigger()
        }
    }

    private func restartSync() {
        syncing = nil
        totalReward = nil
        lastSyncError = nil

        logger?.warning("Reward count changed during sync: restarting")

        DispatchQueue.global().async {
            self.sync()
        }
    }

    private func finalize(with error: Error) {
        totalReward = nil
        lastSyncError = error
        syncing = nil

        logger?.error("Did receive sync error: \(error)")

        DispatchQueue.global().async {
            self.trigger.delegate?.didTrigger()
        }
    }

    private func calculateReward(from remoteItems: [SubqueryHistoryElement]) -> Decimal {
        remoteItems.reduce(Decimal(0.0)) { amount, remoteItem in
            guard
                let rewardOrSlash = remoteItem.reward,
                let nextAmount = BigUInt(rewardOrSlash.amount),
                let nextAmountDecimal = Decimal.fromSubstrateAmount(
                    nextAmount,
                    precision: chain.addressType.precision
                )
            else {
                logger?.error("Broken reward: \(remoteItem)")
                return amount
            }

            return rewardOrSlash.isReward ? amount + nextAmountDecimal : amount - nextAmountDecimal
        }
    }
}

extension SubqueryRewardSource: SingleValueProviderSourceProtocol {
    func fetchOperation() -> CompoundOperationWrapper<Model?> {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        if let reward = totalReward {
            totalReward = nil
            return CompoundOperationWrapper.createWithResult(reward)
        } else if let error = lastSyncError {
            lastSyncError = nil
            return CompoundOperationWrapper.createWithError(error)
        } else {
            sync()
            return createLocalFetchWrapper()
        }
    }
}
