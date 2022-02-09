import Foundation
import RobinHood
import BigInt
import CommonWallet

final class SubqueryRewardSource {
    typealias Model = TotalRewardItem

    let address: String
    let assetPrecision: Int16
    let targetIdentifier: String
    let repository: AnyDataProviderRepository<SingleValueProviderObject>
    let operationFactory: SubqueryRewardOperationFactoryProtocol
    let trigger: DataProviderTriggerProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol?

    private var lastSyncError: Error?
    private var syncing: Bool = false
    private var totalReward: TotalRewardItem?
    private let mutex = NSLock()

    init(
        address: String,
        assetPrecision: Int16,
        targetIdentifier: String,
        repository: AnyDataProviderRepository<SingleValueProviderObject>,
        operationFactory: SubqueryRewardOperationFactoryProtocol,
        trigger: DataProviderTriggerProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.address = address
        self.assetPrecision = assetPrecision
        self.targetIdentifier = targetIdentifier
        self.repository = repository
        self.operationFactory = operationFactory
        self.trigger = trigger
        self.operationManager = operationManager
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
        guard !syncing else {
            return
        }

        syncing = true

        fetch()
    }

    private func fetch() {
        let remoteOperation = operationFactory.createOperation(address: address)

        remoteOperation.completionBlock = {
            DispatchQueue.global(qos: .userInitiated).async {
                self.mutex.lock()

                defer {
                    self.mutex.unlock()
                }

                self.processOperations(remoteOperation: remoteOperation)
            }
        }

        operationManager.enqueue(operations: [remoteOperation], in: .transient)
    }

    private func processOperations(remoteOperation: BaseOperation<SubqueryRewardOrSlashData>) {
        do {
            let remoteData = try remoteOperation.extractNoCancellableResultData()
            let newReward = calculateReward(from: remoteData.historyElements.nodes)

            logger?.debug("New total reward: \(newReward)")

            finalize(with: newReward)
        } catch {
            finalize(with: error)
        }
    }

    private func finalize(with newReward: Decimal) {
        syncing = false

        totalReward = TotalRewardItem(address: address, amount: AmountDecimal(value: newReward))

        DispatchQueue.global().async {
            self.trigger.delegate?.didTrigger()
        }
    }

    private func restartSync() {
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
        syncing = false

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
                    precision: assetPrecision
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
