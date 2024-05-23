import Foundation
import RobinHood
import BigInt

final class SubqueryRewardSource {
    typealias Model = TotalRewardItem

    let address: String
    let assetPrecision: Int16
    let targetIdentifier: String
    let repository: AnyDataProviderRepository<SingleValueProviderObject>
    let rewardsFetcher: StakingRewardsFetcher
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
        rewardsFetcher: StakingRewardsFetcher,
        trigger: DataProviderTriggerProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol? = nil
    ) {
        self.address = address
        self.assetPrecision = assetPrecision
        self.targetIdentifier = targetIdentifier
        self.repository = repository
        self.rewardsFetcher = rewardsFetcher
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
        Task {
            do {
                let rewards = try await rewardsFetcher.fetchAllRewards(
                    address: address,
                    startTimestamp: nil,
                    endTimestamp: nil
                )

                self.processRemoteRewards(rewards)
            } catch {
                self.finalize(with: error)
            }
        }
    }

    private func processRemoteRewards(_ rewards: [RewardOrSlashData]) {
        let newReward = calculateReward(from: rewards)
        logger?.debug("New total reward: \(newReward)")
        finalize(with: newReward)
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

    private func calculateReward(from remoteItems: [RewardOrSlashData]) -> Decimal {
        remoteItems.reduce(Decimal(0.0)) { amount, remoteItem in
            guard
                let rewardOrSlash = remoteItem.rewardInfo
            else {
                logger?.error("Broken reward: \(remoteItem)")
                return amount
            }

            let nextAmountDecimal = getReward(from: rewardOrSlash)

            return rewardOrSlash.isReward ? amount + nextAmountDecimal : amount - nextAmountDecimal
        }
    }

    private func getReward(from rewardOrSlash: RewardOrSlash) -> Decimal {
        if let nextAmount = BigUInt(string: rewardOrSlash.amount),
           let nextAmountDecimal = Decimal.fromSubstrateAmount(
               nextAmount,
               precision: assetPrecision
           ) {
            return nextAmountDecimal
        }

        if let amount = Decimal(string: rewardOrSlash.amount) {
            return amount
        }

        return .zero
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
