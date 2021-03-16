import Foundation
import RobinHood
import FearlessUtils

final class StorageProviderSource<T: Decodable & Equatable>: DataProviderSourceProtocol {
    enum LastSeen: Equatable {
        case waiting
        case received(value: ChainStorageItem?)

        var data: Data? {
            switch self {
            case .waiting:
                return nil
            case .received(let item):
                return item?.data
            }
        }
    }

    typealias Model = ChainStorageDecodedItem<T>

    let itemIdentifier: String
    let codingPath: StorageCodingPath
    let runtimeService: RuntimeCodingServiceProtocol
    let provider: StreamableProvider<ChainStorageItem>
    let trigger: DataProviderTriggerProtocol
    let shouldUseFallback: Bool

    private var lastSeenResult: LastSeen = .waiting
    private var lastSeenError: Error?

    private var lock = NSLock()

    init(itemIdentifier: String,
         codingPath: StorageCodingPath,
         runtimeService: RuntimeCodingServiceProtocol,
         provider: StreamableProvider<ChainStorageItem>,
         trigger: DataProviderTriggerProtocol,
         shouldUseFallback: Bool) {
        self.itemIdentifier = itemIdentifier
        self.codingPath = codingPath
        self.runtimeService = runtimeService
        self.provider = provider
        self.trigger = trigger
        self.shouldUseFallback = shouldUseFallback

        subscribe()
    }

    // MARK: Private

    private func replaceAndNotifyIfNeeded(_ newItem: ChainStorageItem?) {
        let newValue = LastSeen.received(value: newItem)
        if newValue != lastSeenResult || lastSeenError != nil {
            lock.lock()

            lastSeenError = nil
            lastSeenResult = newValue

            lock.unlock()

            trigger.delegate?.didTrigger()
        }
    }

    private func replaceAndNotifyError(_ error: Error) {
        lock.lock()

        lastSeenResult = .waiting
        lastSeenError = error

        lock.unlock()

        trigger.delegate?.didTrigger()
    }

    private func subscribe() {
        let updateClosure = { [weak self] (changes: [DataProviderChange<ChainStorageItem>]) in
            let finalItem: ChainStorageItem? = changes.reduceToLastChange()
            self?.replaceAndNotifyIfNeeded(finalItem)
        }

        let failure = { [weak self] (error: Error) in
            self?.replaceAndNotifyError(error)
            return
        }

        provider.addObserver(self,
                             deliverOn: DispatchQueue.global(qos: .default),
                             executing: updateClosure,
                             failing: failure,
                             options: StreamableProviderObserverOptions.substrateSource())
    }

    private func prepareFallbackBaseOperation() -> CompoundOperationWrapper<T?> {
        if let error = lastSeenError {
            return CompoundOperationWrapper<T?>.createWithError(error)
        }

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let decodingOperation = StorageFallbackDecodingOperation<T>(path: codingPath,
                                                                    data: lastSeenResult.data)
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

        return CompoundOperationWrapper(targetOperation: mappingOperation,
                                        dependencies: [codingFactoryOperation, decodingOperation])
    }

    private func prepareOptionalBaseOperation() -> CompoundOperationWrapper<T?> {
        if let error = lastSeenError {
            return CompoundOperationWrapper<T?>.createWithError(error)
        }

        guard let data = lastSeenResult.data else {
            return CompoundOperationWrapper.createWithResult(nil)
        }

        let codingFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let decodingOperation = StorageDecodingOperation<T>(path: codingPath, data: data)
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

        return CompoundOperationWrapper(targetOperation: mappingOperation,
                                        dependencies: [codingFactoryOperation, decodingOperation])
    }
}

extension StorageProviderSource {
    func fetchOperation(by modelId: String) -> CompoundOperationWrapper<Model?> {
        lock.lock()

        defer {
            lock.unlock()
        }

        guard modelId == itemIdentifier else {
            let value = ChainStorageDecodedItem<T>(identifier: modelId, item: nil)
            return CompoundOperationWrapper<Model?>.createWithResult(value)
        }

        let baseOperationWrapper = shouldUseFallback ? prepareFallbackBaseOperation() :
            prepareOptionalBaseOperation()
        let mappingOperation: BaseOperation<Model?> = ClosureOperation {
            if let item = try baseOperationWrapper.targetOperation.extractNoCancellableResultData() {
                return ChainStorageDecodedItem(identifier: modelId, item: item)
            } else {
                return ChainStorageDecodedItem(identifier: modelId, item: nil)
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

        let baseOperationWrapper = shouldUseFallback ? prepareFallbackBaseOperation() :
            prepareOptionalBaseOperation()
        let mappingOperation: BaseOperation<[Model]> = ClosureOperation {
            if let item = try baseOperationWrapper.targetOperation.extractNoCancellableResultData() {
                return [ChainStorageDecodedItem(identifier: currentId, item: item)]
            } else {
                return [ChainStorageDecodedItem(identifier: currentId, item: nil)]
            }
        }

        let dependencies = baseOperationWrapper.allOperations
        dependencies.forEach { mappingOperation.addDependency($0) }

        return CompoundOperationWrapper(targetOperation: mappingOperation,
                                        dependencies: dependencies)
    }
}
