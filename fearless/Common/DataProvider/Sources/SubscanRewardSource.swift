import Foundation
import RobinHood
import BigInt
import CommonWallet

enum SubscanRewardSourceError: Error {
    case unsupportedAsset
}

enum RewardChange: String, Codable {
    case reward = "Reward"
    case slash = "Slash"
}

final class SubscanRewardSource {
    typealias Model = TotalRewardItem

    struct SyncState {
        let blockNumber: UInt64?
        let extrinsicIndex: UInt16?
        let totalCount: Int?
        let receivedCount: Int
        let reward: Decimal?
    }

    let address: String
    let assetId: WalletAssetId
    let chain: Chain
    let targetIdentifier: String
    let repository: AnyDataProviderRepository<SingleValueProviderObject>
    let operationFactory: SubscanOperationFactoryProtocol
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
        assetId: WalletAssetId,
        chain: Chain,
        targetIdentifier: String,
        repository: AnyDataProviderRepository<SingleValueProviderObject>,
        operationFactory: SubscanOperationFactoryProtocol,
        trigger: DataProviderTriggerProtocol,
        operationManager: OperationManagerProtocol,
        pageSize: Int = 100,
        logger: LoggerProtocol? = nil
    ) {
        self.address = address
        self.assetId = assetId
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
            blockNumber: nil,
            extrinsicIndex: nil,
            totalCount: nil,
            receivedCount: 0,
            reward: nil
        )

        fetch(page: 0)
    }

    private func fetch(page: Int) {
        guard let url = assetId.subscanUrl?.appendingPathComponent(SubscanApi.rewardsAndSlashes) else {
            finalize(with: SubscanRewardSourceError.unsupportedAsset)
            return
        }

        let localWrapper: CompoundOperationWrapper<TotalRewardItem?>

        localWrapper = createLocalFetchWrapper()

        let info = HistoryInfo(
            address: address,
            row: pageSize,
            page: page
        )

        let remoteOperation = operationFactory.fetchRewardsAndSlashesOperation(
            url,
            info: info
        )

        let syncOperation = Operation()

        localWrapper.allOperations.forEach { syncOperation.addDependency($0) }
        syncOperation.addDependency(remoteOperation)

        syncOperation.completionBlock = {
            DispatchQueue.global().async {
                self.mutex.lock()

                defer {
                    self.mutex.unlock()
                }

                self.processOperations(
                    localWrapper.targetOperation,
                    remoteOperation: remoteOperation,
                    page: page
                )
            }
        }

        let allOperations = localWrapper.allOperations + [remoteOperation, syncOperation]
        operationManager.enqueue(operations: allOperations, in: .transient)
    }

    private func processOperations(
        _ localOperation: BaseOperation<TotalRewardItem?>,
        remoteOperation: BaseOperation<SubscanRewardData>,
        page: Int
    ) {
        do {
            let totalReward = try localOperation.extractNoCancellableResultData()
            let remoteData = try remoteOperation.extractNoCancellableResultData()

            if let expectedCount = syncing?.totalCount, expectedCount != remoteData.count {
                restartSync()
                return
            }

            let endIndex: Int?

            if let reward = totalReward {
                endIndex = remoteData.items?.firstIndex {
                    $0.blockNumber == reward.blockNumber && $0.extrinsicIndex == reward.extrinsicIndex
                }
            } else {
                endIndex = nil
            }

            let allRemoteItems = remoteData.items ?? []
            let count = endIndex ?? allRemoteItems.count

            let newRemoteItems = Array(allRemoteItems[0 ..< count])
            let pageReward = calculateReward(from: newRemoteItems)

            let newBlockNum = (syncing?.blockNumber != nil) ? syncing?.blockNumber :
                newRemoteItems.first?.blockNumber
            let newExtrinsicIndex = (syncing?.extrinsicIndex != nil) ? syncing?.extrinsicIndex :
                newRemoteItems.first?.extrinsicIndex
            let receivedCount = (syncing?.receivedCount ?? 0) + newRemoteItems.count

            syncing = SyncState(
                blockNumber: newBlockNum,
                extrinsicIndex: newExtrinsicIndex,
                totalCount: remoteData.count,
                receivedCount: receivedCount,
                reward: (syncing?.reward ?? 0.0) + pageReward
            )

            logger?.debug("Did complete sync of \(receivedCount) of \(remoteData.count)")
            logger?.debug("Block number: \(String(describing: newBlockNum))")
            logger?.debug("Extrinsic index: \(String(describing: newExtrinsicIndex))")
            logger?.debug("Page reward: \(pageReward)")

            if endIndex != nil || receivedCount >= remoteData.count {
                finalize(with: totalReward)
            } else {
                fetch(page: page + 1)
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

        if let blockNum = syncState.blockNumber,
           let extrinsicIndex = syncState.extrinsicIndex,
           let reward = syncState.reward {
            let newAmount = reward + (previousReward?.amount.decimalValue ?? 0.0)
            totalReward = TotalRewardItem(
                address: address,
                blockNumber: blockNum,
                extrinsicIndex: extrinsicIndex,
                amount: AmountDecimal(value: newAmount)
            )

            syncing = nil

            logger?.debug("Did receive new reward: \(reward)")
        } else {
            logger?.debug("Sync completed: nothing changed")

            totalReward = TotalRewardItem(
                address: address,
                blockNumber: previousReward?.blockNumber,
                extrinsicIndex: previousReward?.extrinsicIndex,
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

    private func calculateReward(from remoteItems: [SubscanRewardItemData]) -> Decimal {
        remoteItems.reduce(Decimal(0.0)) { amount, remoteItem in
            guard
                let nextAmount = BigUInt(remoteItem.amount),
                let nextAmountDecimal = Decimal
                .fromSubstrateAmount(nextAmount, precision: chain.addressType.precision),
                let change = RewardChange(rawValue: remoteItem.eventId)
            else {
                logger?.error("Broken reward: \(remoteItem)")
                return amount
            }

            switch change {
            case .reward:
                return amount + nextAmountDecimal
            case .slash:
                return amount - nextAmountDecimal
            }
        }
    }
}

extension SubscanRewardSource: SingleValueProviderSourceProtocol {
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
