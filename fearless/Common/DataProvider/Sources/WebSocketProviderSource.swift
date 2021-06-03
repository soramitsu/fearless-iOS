import Foundation
import RobinHood
import FearlessUtils

typealias WebSocketProviderKeyClosure = (@escaping () throws -> RuntimeCoderFactoryProtocol) throws
    -> BaseOperation<[Data]>

enum WebSocketProviderSourceError: Error {
    case noKeysFound
}

final class WebSocketProviderSource<T: Decodable & Equatable>: DataProviderSourceProtocol {
    enum LastSeen: Equatable {
        case waiting
        case received(value: Data?)

        var data: Data? {
            switch self {
            case .waiting:
                return nil
            case let .received(value):
                return value
            }
        }
    }

    typealias Model = ChainStorageDecodedItem<T>

    let itemIdentifier: String
    let codingPath: StorageCodingPath
    let runtimeService: RuntimeCodingServiceProtocol
    let keyOperationClosure: WebSocketProviderKeyClosure
    let engine: JSONRPCEngine
    let trigger: DataProviderTriggerProtocol
    let operationManager: OperationManagerProtocol

    private var lastSeenResult: LastSeen = .waiting
    private var lastSeenError: Error?
    private var subscriptionId: UInt16?

    private var mutex = NSLock()

    init(
        itemIdentifier: String,
        codingPath: StorageCodingPath,
        keyOperationClosure: @escaping WebSocketProviderKeyClosure,
        runtimeService: RuntimeCodingServiceProtocol,
        engine: JSONRPCEngine,
        trigger: DataProviderTriggerProtocol,
        operationManager: OperationManagerProtocol
    ) {
        self.itemIdentifier = itemIdentifier
        self.codingPath = codingPath
        self.keyOperationClosure = keyOperationClosure
        self.runtimeService = runtimeService
        self.engine = engine
        self.trigger = trigger
        self.operationManager = operationManager

        generateKeyAndSubscribe()
    }

    deinit {
        unsubscribe()
    }

    // MARK: Private

    private func replaceAndNotifyIfNeeded(_ newData: Data?) {
        let newValue = LastSeen.received(value: newData)
        if newValue != lastSeenResult || lastSeenError != nil {
            mutex.lock()

            lastSeenError = nil
            lastSeenResult = newValue

            mutex.unlock()

            trigger.delegate?.didTrigger()
        }
    }

    private func replaceAndNotifyError(_ error: Error) {
        mutex.lock()

        lastSeenResult = .waiting
        lastSeenError = error

        mutex.unlock()

        trigger.delegate?.didTrigger()
    }

    private func generateKeyAndSubscribe() {
        do {
            let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

            let keyOperation = try keyOperationClosure {
                try coderFactoryOperation.extractNoCancellableResultData()
            }

            keyOperation.addDependency(coderFactoryOperation)

            keyOperation.completionBlock = { [weak self] in
                DispatchQueue.global(qos: .default).async {
                    do {
                        let keys = try keyOperation.extractNoCancellableResultData()

                        if let key = keys.first {
                            self?.subscribe(for: key)
                        } else {
                            self?.replaceAndNotifyError(WebSocketProviderSourceError.noKeysFound)
                        }
                    } catch {
                        self?.replaceAndNotifyError(error)
                    }
                }
            }

            operationManager.enqueue(operations: [coderFactoryOperation, keyOperation], in: .transient)

        } catch {
            replaceAndNotifyError(error)
        }
    }

    private func subscribe(for key: Data) {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard subscriptionId == nil else {
            return
        }

        do {
            let updateClosure: (StorageSubscriptionUpdate) -> Void = { [weak self] update in
                self?.handleUpdate(update, for: key)
            }

            let failureClosure: (Error, Bool) -> Void = { [weak self] error, _ in
                self?.replaceAndNotifyError(error)
            }

            let keyHex = key.toHex(includePrefix: true)

            let subscriptionId = try engine.subscribe(
                RPCMethod.storageSubscibe,
                params: [[keyHex]],
                updateClosure: updateClosure,
                failureClosure: failureClosure
            )

            self.subscriptionId = subscriptionId

        } catch {
            replaceAndNotifyError(error)
        }
    }

    private func unsubscribe() {
        mutex.lock()

        if let subscriptionId = subscriptionId {
            engine.cancelForIdentifier(subscriptionId)
        }

        subscriptionId = nil

        mutex.unlock()
    }

    private func handleUpdate(_ update: StorageSubscriptionUpdate, for key: Data) {
        let updateData = StorageUpdateData(update: update.params.result)
        guard let updateForKey = updateData.changes.first(where: { $0.key == key }) else {
            return
        }

        replaceAndNotifyIfNeeded(updateForKey.value)
    }

    private func prepareModifierBasedDecodingOperation() -> CompoundOperationWrapper<T?> {
        if let error = lastSeenError {
            return CompoundOperationWrapper<T?>.createWithError(error)
        }

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let decodingOperation = StorageFallbackDecodingOperation<T>(
            path: codingPath,
            data: lastSeenResult.data
        )
        decodingOperation.configurationBlock = {
            do {
                decodingOperation.codingFactory = try codingFactoryOperation.extractNoCancellableResultData()
            } catch {
                decodingOperation.result = .failure(error)
            }
        }

        decodingOperation.addDependency(codingFactoryOperation)

        let mappingOperation: BaseOperation<T?> = ClosureOperation {
            try decodingOperation.extractNoCancellableResultData()
        }

        mappingOperation.addDependency(decodingOperation)

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: [codingFactoryOperation, decodingOperation]
        )
    }
}

extension WebSocketProviderSource {
    func fetchOperation(by modelId: String) -> CompoundOperationWrapper<Model?> {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        guard modelId == itemIdentifier else {
            let value = ChainStorageDecodedItem<T>(identifier: modelId, item: nil)
            return CompoundOperationWrapper<Model?>.createWithResult(value)
        }

        let baseOperationWrapper = prepareModifierBasedDecodingOperation()
        let mappingOperation: BaseOperation<Model?> = ClosureOperation {
            if let item = try baseOperationWrapper.targetOperation.extractNoCancellableResultData() {
                return ChainStorageDecodedItem(identifier: modelId, item: item)
            } else {
                return ChainStorageDecodedItem(identifier: modelId, item: nil)
            }
        }

        let dependencies = baseOperationWrapper.allOperations
        dependencies.forEach { mappingOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: dependencies
        )
    }

    func fetchOperation(page _: UInt) -> CompoundOperationWrapper<[Model]> {
        mutex.lock()

        defer {
            mutex.unlock()
        }

        let currentId = itemIdentifier

        let baseOperationWrapper = prepareModifierBasedDecodingOperation()
        let mappingOperation: BaseOperation<[Model]> = ClosureOperation {
            if let item = try baseOperationWrapper.targetOperation.extractNoCancellableResultData() {
                return [ChainStorageDecodedItem(identifier: currentId, item: item)]
            } else {
                return [ChainStorageDecodedItem(identifier: currentId, item: nil)]
            }
        }

        let dependencies = baseOperationWrapper.allOperations
        dependencies.forEach { mappingOperation.addDependency($0) }

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: dependencies
        )
    }
}
