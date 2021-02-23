import Foundation
import RobinHood
import FearlessUtils

enum StorageProviderSourceError: Error {
    case unsupportedId
    case unsupportedStorage
}

final class StorageProviderSource<T: Decodable & Equatable>: DataProviderSourceProtocol {
    typealias Model = ChainStorageDecodedItem<T>

    let itemIdentifier: String
    let decodingModuleName: String
    let decodingStorageName: String
    let runtimeService: RuntimeCodingServiceProtocol
    let provider: StreamableProvider<ChainStorageItem>
    let trigger: DataProviderTriggerProtocol

    private var lastSeenResult: ChainStorageItem?
    private var lastSeenError: Error?

    private var lock = NSLock()

    init(itemIdentifier: String,
         decodingModuleName: String,
         decodingStorageName: String,
         runtimeService: RuntimeCodingServiceProtocol,
         provider: StreamableProvider<ChainStorageItem>,
         trigger: DataProviderTriggerProtocol) {
        self.itemIdentifier = itemIdentifier
        self.decodingModuleName = decodingModuleName
        self.decodingStorageName = decodingStorageName
        self.runtimeService = runtimeService
        self.provider = provider
        self.trigger = trigger

        subscribe()
    }

    // MARK: Private

    private func replaceAndNotifyIfNeeded(_ newItem: ChainStorageItem?) {
        if newItem != lastSeenResult || lastSeenError != nil {
            lock.lock()

            lastSeenError = nil
            lastSeenResult = newItem

            lock.unlock()

            trigger.delegate?.didTrigger()
        }
    }

    private func replaceAndNotifyError(_ error: Error) {
        lock.lock()

        lastSeenResult = nil
        lastSeenError = error

        lock.unlock()

        trigger.delegate?.didTrigger()
    }

    private func subscribe() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<ChainStorageItem>]) in
            let finalItem: ChainStorageItem? = changes.reduce(nil) { (_, item) in
                switch item {
                case .insert(let newItem), .update(let newItem):
                    return newItem
                case .delete:
                    return nil
                }
            }

            self?.replaceAndNotifyIfNeeded(finalItem)
        }

        let failure = { [weak self] (error: Error) in
            self?.replaceAndNotifyError(error)
            return
        }

        let options = StreamableProviderObserverOptions(alwaysNotifyOnRefresh: false,
                                                        waitsInProgressSyncOnAdd: false,
                                                        initialSize: 0,
                                                        refreshWhenEmpty: false)
        provider.addObserver(self,
                             deliverOn: DispatchQueue.global(qos: .default),
                             executing: updateClosure,
                             failing: failure,
                             options: options)
    }

    private func prepareBaseOperation() -> CompoundOperationWrapper<T?> {
        if let error = lastSeenError {
            return CompoundOperationWrapper<T?>.createWithError(error)
        }

        guard let data = lastSeenResult?.data else {
            return CompoundOperationWrapper<T?>.createWithResult(nil)
        }

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let moduleName = decodingModuleName
        let storageName = decodingStorageName

        let decodingOperation: BaseOperation<T?> = ClosureOperation {
            let factory = try codingFactoryOperation.extractNoCancellableResultData()

            guard let typeName = factory.metadata
                    .getStorageMetadata(in: moduleName,
                                        storageName: storageName)?.type.typeName else {
                throw StorageProviderSourceError.unsupportedStorage
            }

            let decoder = try factory.createDecoder(from: data)
            let item: T = try decoder.read(of: typeName)
            return item
        }

        decodingOperation.addDependency(codingFactoryOperation)

        return CompoundOperationWrapper(targetOperation: decodingOperation,
                                        dependencies: [codingFactoryOperation])
    }
}

extension StorageProviderSource {
    func fetchOperation(by modelId: String) -> CompoundOperationWrapper<Model?> {
        lock.lock()

        defer {
            lock.unlock()
        }

        guard modelId == itemIdentifier else {
            return CompoundOperationWrapper<Model?>.createWithResult(nil)
        }

        let baseOperationWrapper = prepareBaseOperation()
        let mappingOperation: BaseOperation<Model?> = ClosureOperation {
            if let item = try baseOperationWrapper.targetOperation.extractNoCancellableResultData() {
                return ChainStorageDecodedItem(identifier: modelId, item: item)
            } else {
                return nil
            }
        }

        let dependencies = baseOperationWrapper.allOperations
        dependencies.forEach { mappingOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mappingOperation,
                                        dependencies: dependencies)
    }

    func fetchOperation(page index: UInt) -> CompoundOperationWrapper<[Model]> {
        lock.lock()

        defer {
            lock.unlock()
        }

        let currentId = itemIdentifier

        let baseOperationWrapper = prepareBaseOperation()
        let mappingOperation: BaseOperation<[Model]> = ClosureOperation {
            if let item = try baseOperationWrapper.targetOperation.extractNoCancellableResultData() {
                return [ChainStorageDecodedItem(identifier: currentId, item: item)]
            } else {
                return []
            }
        }

        let dependencies = baseOperationWrapper.allOperations
        dependencies.forEach { mappingOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mappingOperation,
                                        dependencies: dependencies)
    }
}
