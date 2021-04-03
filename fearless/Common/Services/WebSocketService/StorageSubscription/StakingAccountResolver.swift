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
        let ledger: DyStakingLedger?
    }

    let address: String
    let chain: Chain
    let engine: JSONRPCEngine
    let runtimeService: RuntimeCodingServiceProtocol
    let childSubscriptionFactory: ChildSubscriptionFactoryProtocol
    let addressFactory: SS58AddressFactoryProtocol
    let operationManager: OperationManagerProtocol
    let repository: AnyDataProviderRepository<StashItem>
    let logger: LoggerProtocol?

    private let mutex = NSLock()

    private var subscription: Subscription?

    init(
        address: String,
        chain: Chain,
        engine: JSONRPCEngine,
        runtimeService: RuntimeCodingServiceProtocol,
        repository: AnyDataProviderRepository<StashItem>,
        childSubscriptionFactory: ChildSubscriptionFactoryProtocol,
        addressFactory: SS58AddressFactoryProtocol,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol?
    ) {
        self.address = address
        self.chain = chain
        self.engine = engine
        self.runtimeService = runtimeService
        self.childSubscriptionFactory = childSubscriptionFactory
        self.repository = repository
        self.addressFactory = addressFactory
        self.operationManager = operationManager
        self.logger = logger

        resolveKeysAndSubscribe()
    }

    deinit {
        unsubscribe()
    }

    private func resolveKeysAndSubscribe() {
        do {
            let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let accountId = try addressFactory.accountId(fromAddress: address, type: chain.addressType)

            let storageKeyFactory = StorageKeyFactory()

            let controllerOperation = MapKeyEncodingOperation(
                path: .controller,
                storageKeyFactory: storageKeyFactory,
                keyParams: [accountId]
            )

            let ledgerOperation = MapKeyEncodingOperation(
                path: .stakingLedger,
                storageKeyFactory: storageKeyFactory,
                keyParams: [accountId]
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

                    self?.subscribe(with: controllerKey, ledgerKey: ledgerKey)
                } catch {
                    self?.logger?.error("Did receiver error: \(error)")
                }
            }

            let operations = [codingFactoryOperation, controllerOperation, ledgerOperation, syncOperation]

            operationManager.enqueue(operations: operations, in: .transient)

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

        engine.cancelForIdentifier(subscription.subscriptionId)
        self.subscription = nil
    }

    private func subscribe(with controllerKey: Data, ledgerKey: Data) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        do {
            let controllerSubscription = childSubscriptionFactory
                .createEmptyHandlingSubscription(remoteKey: controllerKey)
            let ledgerSubscription = childSubscriptionFactory
                .createEventEmittingSubscription(
                    remoteKey: ledgerKey,
                    eventFactory: { _ in WalletStakingInfoChanged() }
                )

            let storageParams = [
                controllerKey.toHex(includePrefix: true),
                ledgerKey.toHex(includePrefix: true)
            ]

            let updateClosure: (StorageSubscriptionUpdate) -> Void = { [weak self] update in
                self?.handleUpdate(update.params.result)
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] error, unsubscribed in
                self?.logger?.error("Did receive subscription error: \(error) \(unsubscribed)")
            }

            let subscriptionId = try engine.subscribe(
                RPCMethod.storageSubscibe,
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
            initAddress: address,
            type: chain.addressType,
            addressFactory: addressFactory
        )
        processingOperation.addDependency(decodingWrapper.targetOperation)
        let saveWrapper = createSaveWrapper(dependingOn: processingOperation)
        saveWrapper.allOperations.forEach { $0.addDependency(processingOperation) }

        let operations = decodingWrapper.allOperations + [processingOperation] + saveWrapper.allOperations

        operationManager.enqueue(operations: operations, in: .transient)
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
        let codingFactory = runtimeService.fetchCoderFactoryOperation()

        let controllerDecoding: BaseOperation<Data>? = createDecodingOperation(
            for: subscription.controller,
            path: .controller,
            updateData: updateData,
            coderOperation: codingFactory
        )
        controllerDecoding?.addDependency(codingFactory)

        let ledgerDecoding: BaseOperation<DyStakingLedger>? =
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
        initAddress: String,
        type: SNAddressType,
        addressFactory: SS58AddressFactoryProtocol
    ) -> BaseOperation<StashItem?> {
        ClosureOperation<StashItem?> {
            let changes = try decodinigOperation.extractNoCancellableResultData()
            if let controller = changes.controller {
                let controllerAddress = try addressFactory.addressFromAccountId(data: controller, type: type)
                return StashItem(stash: initAddress, controller: controllerAddress)
            }

            if let stash = changes.ledger?.stash {
                let stashAddress = try addressFactory.addressFromAccountId(data: stash, type: type)
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
