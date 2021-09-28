import Foundation
import RobinHood
import IrohaCrypto
import FearlessUtils

final class StakingAccountResolver: WebSocketSubscribing {
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
    let chainId: ChainModel.Id
    let chainFormat: ChainFormat
    let chainRegistry: ChainRegistryProtocol
    let childSubscriptionFactory: ChildSubscriptionFactoryProtocol
    let operationQueue: OperationQueue
    let repository: AnyDataProviderRepository<StashItem>
    let logger: LoggerProtocol?

    private let mutex = NSLock()

    private var subscription: Subscription?

    init(
        accountId: AccountId,
        chainId: ChainModel.Id,
        chainFormat: ChainFormat,
        chainRegistry: ChainRegistryProtocol,
        childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
        operationQueue: OperationQueue,
        repository: AnyDataProviderRepository<StashItem>,
        logger: LoggerProtocol? = nil
    ) {
        self.accountId = accountId
        self.chainId = chainId
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

    private func resolveKeysAndSubscribe() {
        do {
            guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
                throw ChainRegistryError.runtimeMetadaUnavailable
            }

            let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let storageKeyFactory = StorageKeyFactory()

            let controllerOperation = MapKeyEncodingOperation(
                path: .controller,
                storageKeyFactory: storageKeyFactory,
                keyParams: [accountId]
            )

            let localKeyFactory = LocalStorageKeyFactory()
            let controllerLocalKey = try localKeyFactory.createFromStoragePath(
                .controller,
                accountId: accountId,
                chainId: chainId
            )

            let ledgerOperation = MapKeyEncodingOperation(
                path: .stakingLedger,
                storageKeyFactory: storageKeyFactory,
                keyParams: [accountId]
            )

            let ledgerLocalKey = try localKeyFactory.createFromStoragePath(
                .stakingLedger,
                accountId: accountId,
                chainId: chainId
            )

            [controllerOperation, ledgerOperation].forEach { operation in
                operation.addDependency(codingFactoryOperation)

                operation.configurationBlock = {
                    do {
                        operation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
                    } catch {
                        operation.result = .failure(error)
                    }
                }
            }

            let syncOperation = Operation()
            syncOperation.addDependency(controllerOperation)
            syncOperation.addDependency(ledgerOperation)

            syncOperation.completionBlock = { [weak self] in
                do {
                    let controllerKey = try controllerOperation.extractNoCancellableResultData()[0]
                    let ledgerKey = try ledgerOperation.extractNoCancellableResultData()[0]

                    self?.subscribe(
                        with: SubscriptionStorageKeys(remote: controllerKey, local: controllerLocalKey),
                        ledgerKeys: SubscriptionStorageKeys(remote: ledgerKey, local: ledgerLocalKey)
                    )
                } catch {
                    self?.logger?.error("Did receiver error: \(error)")
                }
            }

            let operations = [codingFactoryOperation, controllerOperation, ledgerOperation, syncOperation]

            operationQueue.addOperations(operations, waitUntilFinished: false)

        } catch {
            logger?.error("Did receive error: \(error)")
        }
    }

    private func unsubscribe() {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard let subscription = subscription else {
            return
        }

        chainRegistry.getConnection(for: chainId)?.cancelForIdentifier(subscription.subscriptionId)
        self.subscription = nil
    }

    private func subscribe(
        with controllerKeys: SubscriptionStorageKeys,
        ledgerKeys: SubscriptionStorageKeys
    ) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        do {
            guard let connection = chainRegistry.getConnection(for: chainId) else {
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

    private func handleUpdate(_ update: StorageUpdate) {
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

    private func updateChild(subscription: StorageChildSubscribing, for update: StorageUpdateData) {
        if let change = update.changes.first(where: { $0.key == subscription.remoteStorageKey }) {
            subscription.processUpdate(change.value, blockHash: update.blockHash)
        }
    }
}

extension StakingAccountResolver {
    private func createDecodingWrapper(
        from updateData: StorageUpdateData,
        subscription: Subscription
    ) -> CompoundOperationWrapper<DecodedChanges> {
        guard let runtimeService = chainRegistry.getRuntimeProvider(for: chainId) else {
            return CompoundOperationWrapper.createWithError(ChainRegistryError.runtimeMetadaUnavailable)
        }

        let codingFactory = runtimeService.fetchCoderFactoryOperation()

        let controllerDecoding: BaseOperation<Data>? = createDecodingOperation(
            for: subscription.controller,
            path: .controller,
            updateData: updateData,
            coderOperation: codingFactory
        )
        controllerDecoding?.addDependency(codingFactory)

        let ledgerDecoding: BaseOperation<StakingLedger>? =
            createDecodingOperation(
                for: subscription.ledger,
                path: .stakingLedger,
                updateData: updateData,
                coderOperation: codingFactory
            )
        ledgerDecoding?.addDependency(codingFactory)

        let mapOperation = ClosureOperation<DecodedChanges> {
            let controller = try controllerDecoding?.extractNoCancellableResultData()
            let ledger = try ledgerDecoding?.extractNoCancellableResultData()

            return DecodedChanges(controller: controller, ledger: ledger)
        }

        var dependencies: [Operation] = [codingFactory]

        if let operation = controllerDecoding {
            dependencies.append(operation)
        }

        if let operation = ledgerDecoding {
            dependencies.append(operation)
        }

        dependencies.forEach { mapOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mapOperation, dependencies: dependencies)
    }

    private func createDecodingOperation<T>(
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

    private func createProcessingOperation(
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

    private func createSaveWrapper(
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
