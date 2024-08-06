import Foundation
import RobinHood
import IrohaCrypto
import SSFUtils
import SSFModels
import SSFRuntimeCodingService

class BaseStakingAccountResolver: StakingAccountResolver {
    struct Subscription {
        let controller: StorageChildSubscribing
        let ledger: StorageChildSubscribing
        let subscriptionId: UInt16
    }

    struct DecodedChanges {
        let controller: Data?
        let ledger: StakingLedger?
    }

    let accountId: AccountId
    let chainAsset: ChainAsset
    let chainRegistry: ChainRegistryProtocol
    let operationQueue: OperationQueue
    let logger: LoggerProtocol?

    private let chainFormat: ChainFormat
    private let childSubscriptionFactory: ChildSubscriptionFactoryProtocol
    private let repository: AnyDataProviderRepository<StashItem>
    private let mutex = NSLock()
    private var subscription: Subscription?

    init(
        accountId: AccountId,
        chainAsset: ChainAsset,
        chainFormat: ChainFormat,
        chainRegistry: ChainRegistryProtocol,
        childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        repository: AnyDataProviderRepository<StashItem>,
        logger: LoggerProtocol? = nil
    ) {
        self.accountId = accountId
        self.chainAsset = chainAsset
        self.chainFormat = chainFormat
        self.chainRegistry = chainRegistry
        self.childSubscriptionFactory = childSubscriptionFactory
        self.repository = repository
        self.operationQueue = operationQueue
        self.logger = logger

        resolveKeysAndSubscribe()
    }

    deinit {
        unsubscribe()
    }

    func resolveKeysAndSubscribe() {
        preconditionFailure("You cannot use base implementation of BaseStakingAccountResolver, please override it")
    }

    func createDecodingWrapper(
        from _: StorageUpdateData,
        subscription _: Subscription
    ) -> CompoundOperationWrapper<DecodedChanges> {
        preconditionFailure("You cannot use base implementation of BaseStakingAccountResolver, please override it")
    }

    func unsubscribe() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard let subscription = subscription else {
            return
        }

        chainRegistry.getConnection(for: chainAsset.chain.chainId)?.cancelForIdentifier(subscription.subscriptionId)
        self.subscription = nil
    }

    func subscribe(
        with controllerKeys: SubscriptionStorageKeys,
        ledgerKeys: SubscriptionStorageKeys
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        do {
            guard let connection = chainRegistry.getConnection(for: chainAsset.chain.chainId) else {
                throw ChainRegistryError.connectionUnavailable
            }

            let controllerSubscription = childSubscriptionFactory.createEmptyHandlingSubscription(
                keys: controllerKeys
            )
            let ledgerSubscription = childSubscriptionFactory.createEmptyHandlingSubscription(
                keys: ledgerKeys
            )

            let storageParams = [
                controllerKeys.remote.toHex(includePrefix: true),
                ledgerKeys.remote.toHex(includePrefix: true)
            ]

            let updateClosure: (StorageSubscriptionUpdate) -> Void = { [weak self] update in
                self?.handleUpdate(update.params.result)
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] error, unsubscribed in
                self?.logger?.error("Did receive subscription error: \(error) \(unsubscribed)")
            }

            let subscriptionId = try connection.subscribe(
                RPCMethod.storageSubscribe,
                params: [storageParams],
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )

            subscription = Subscription(
                controller: controllerSubscription,
                ledger: ledgerSubscription,
                subscriptionId: subscriptionId
            )
        } catch {
            logger?.error("Did receive error: \(error)")
        }
    }

    func handleUpdate(_ update: StorageUpdate) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard let subscription = subscription else {
            logger?.warning("Staking update received but subscription is missing")
            return
        }

        let updateData = StorageUpdateData(update: update)
        updateChild(subscription: subscription.controller, for: updateData)
        updateChild(subscription: subscription.ledger, for: updateData)

        let decodingWrapper = createDecodingWrapper(from: updateData, subscription: subscription)
        let processingOperation = createProcessingOperation(
            dependingOn: decodingWrapper.targetOperation,
            initAccountId: accountId,
            chainFormat: chainFormat
        )
        processingOperation.addDependency(decodingWrapper.targetOperation)
        let saveWrapper = createSaveWrapper(dependingOn: processingOperation)
        saveWrapper.allOperations.forEach { $0.addDependency(processingOperation) }

        let operations = decodingWrapper.allOperations + [processingOperation] + saveWrapper.allOperations

        operationQueue.addOperations(operations, waitUntilFinished: false)
    }

    func updateChild(subscription: StorageChildSubscribing, for update: StorageUpdateData) {
        if let change = update.changes.first(where: { $0.key == subscription.remoteStorageKey }) {
            subscription.processUpdate(change.value, blockHash: update.blockHash)
        }
    }

    func createDecodingOperation<T>(
        for subscription: StorageChildSubscribing,
        path: StorageCodingPath,
        updateData: StorageUpdateData,
        coderOperation: BaseOperation<RuntimeCoderFactoryProtocol>
    ) -> BaseOperation<T>? where T: Decodable {
        if let ledgerValue = updateData.changes
            .first(where: { $0.key == subscription.remoteStorageKey })?.value {
            let operation = StorageDecodingOperation<T>(path: path, data: ledgerValue)
            operation.configurationBlock = {
                do {
                    operation.codingFactory = try coderOperation.extractNoCancellableResultData()
                } catch {
                    operation.result = .failure(error)
                }
            }

            return operation
        } else {
            return nil
        }
    }

    func createProcessingOperation(
        dependingOn decodinigOperation: BaseOperation<DecodedChanges>,
        initAccountId: AccountId,
        chainFormat: ChainFormat
    ) -> BaseOperation<StashItem?> {
        ClosureOperation<StashItem?> {
            let initAddress = try initAccountId.toAddress(using: chainFormat)
            let changes = try decodinigOperation.extractNoCancellableResultData()
            if let controller = changes.controller {
                let controllerAddress = try controller.toAddress(using: chainFormat)
                return StashItem(stash: initAddress, controller: controllerAddress)
            }

            if let stash = changes.ledger?.stash {
                let stashAddress = try stash.toAddress(using: chainFormat)
                return StashItem(stash: stashAddress, controller: initAddress)
            }

            return nil
        }
    }

    func createSaveWrapper(
        dependingOn operation: BaseOperation<StashItem?>
    ) -> CompoundOperationWrapper<Void> {
        let currentItemsOperation = repository.fetchAllOperation(with: RepositoryFetchOptions())

        let saveOperation = repository.saveOperation({
            let currentItem = try currentItemsOperation.extractNoCancellableResultData()
                .first

            if let newStashItem = try operation.extractNoCancellableResultData(),
               currentItem != newStashItem {
                return [newStashItem]
            } else {
                return []
            }
        }, {
            let newStashItem = try operation.extractNoCancellableResultData()

            guard let currentId = try currentItemsOperation.extractNoCancellableResultData()
                .first?.identifier
            else {
                return []
            }

            if newStashItem == nil || newStashItem?.stash != currentId {
                return [currentId]
            } else {
                return []
            }
        })

        saveOperation.addDependency(currentItemsOperation)

        return CompoundOperationWrapper(targetOperation: saveOperation, dependencies: [currentItemsOperation])
    }
}
