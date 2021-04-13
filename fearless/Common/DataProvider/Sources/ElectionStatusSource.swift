import Foundation
import RobinHood
import FearlessUtils

final class ElectionStatusSource: DataProviderSourceProtocol {
    enum LastSeen {
        case waiting
        case received(value: ChainStorageItem?, shouldDecodeAsPhase: Bool)
        case failure(error: Error)

        var data: Data? {
            switch self {
            case .waiting:
                return nil
            case let .received(item, _):
                return item?.data
            case .failure:
                return nil
            }
        }

        var shouldDecodeAsPhase: Bool? {
            switch self {
            case .waiting:
                return nil
            case let .received(_, shouldDecodeAsPhase):
                return shouldDecodeAsPhase
            case .failure:
                return nil
            }
        }

        var error: Error? {
            if case let .failure(error) = self {
                return error
            } else {
                return nil
            }
        }
    }

    typealias Model = ChainStorageDecodedItem<ElectionStatus>

    let itemIdentifier: String
    let localKeyFactory: ChainStorageIdFactoryProtocol
    let runtimeService: RuntimeCodingServiceProtocol
    let providerFactory: SubstrateDataProviderFactoryProtocol
    let trigger: DataProviderTriggerProtocol
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol?

    private var lastSeenResult: LastSeen = .waiting
    private var provider: StreamableProvider<ChainStorageItem>?

    private var lock = NSLock()

    init(
        itemIdentifier: String,
        localKeyFactory: ChainStorageIdFactoryProtocol,
        runtimeService: RuntimeCodingServiceProtocol,
        providerFactory: SubstrateDataProviderFactoryProtocol,
        operationManager: OperationManagerProtocol,
        trigger: DataProviderTriggerProtocol,
        logger: LoggerProtocol?
    ) {
        self.itemIdentifier = itemIdentifier
        self.localKeyFactory = localKeyFactory
        self.runtimeService = runtimeService
        self.providerFactory = providerFactory
        self.operationManager = operationManager
        self.trigger = trigger
        self.logger = logger

        resolveKeyAndSubscribe()
    }

    // MARK: Private

    private func replaceAndNotifyIfNeeded(_ newItem: ChainStorageItem?, shouldDecodeAsPhase: Bool) {
        if updateResultIfNeeded(newItem, shouldDecodeAsPhase: shouldDecodeAsPhase) {
            trigger.delegate?.didTrigger()
        }
    }

    private func updateResultIfNeeded(_ newItem: ChainStorageItem?, shouldDecodeAsPhase: Bool) -> Bool {
        lock.lock()

        defer {
            lock.unlock()
        }

        let newValue = LastSeen.received(value: newItem, shouldDecodeAsPhase: shouldDecodeAsPhase)

        if
            newValue.data != lastSeenResult.data ||
            newValue.shouldDecodeAsPhase != lastSeenResult.shouldDecodeAsPhase {
            lastSeenResult = newValue

            return true
        } else {
            return false
        }
    }

    private func replaceAndNotifyError(_ error: Error) {
        lock.lock()

        lastSeenResult = .failure(error: error)

        provider?.removeObserver(self)
        provider = nil

        lock.unlock()

        trigger.delegate?.didTrigger()
    }

    private func resolveKeyAndSubscribe() {
        lastSeenResult = .waiting

        let coderFactoryOperation = runtimeService.fetchCoderFactoryOperation()

        let remoteKeyOperation = ClosureOperation<(Data, Bool)?> {
            let metadata = try coderFactoryOperation.extractNoCancellableResultData().metadata

            let storageKeyFactory = StorageKeyFactory()

            if metadata.getStorageMetadata(for: .electionStatus) != nil {
                let key = try storageKeyFactory.key(from: .electionStatus)
                return (key, false)
            }

            if metadata.getStorageMetadata(for: .electionPhase) != nil {
                let key = try storageKeyFactory.key(from: .electionPhase)
                return (key, true)
            }

            return nil
        }

        remoteKeyOperation.addDependency(coderFactoryOperation)

        remoteKeyOperation.completionBlock = { [weak self] in
            self?.handleRemoteKey(result: remoteKeyOperation.result)
        }

        operationManager.enqueue(operations: [coderFactoryOperation, remoteKeyOperation], in: .transient)
    }

    private func handleRemoteKey(result: Result<(Data, Bool)?, Error>?) {
        switch result {
        case let .success(remoteKeyTuple):
            if let remoteKeyTuple = remoteKeyTuple {
                subscribe(to: remoteKeyTuple.0, shouldDecodeAsPhase: remoteKeyTuple.1)
            } else {
                replaceAndNotifyError(CommonError.undefined)
            }
        case let .failure(error):
            replaceAndNotifyError(error)
        case .none:
            replaceAndNotifyError(CommonError.undefined)
        }
    }

    private func subscribe(to remoteKey: Data, shouldDecodeAsPhase: Bool) {
        let updateClosure = { [weak self] (changes: [DataProviderChange<ChainStorageItem>]) in
            let finalItem: ChainStorageItem? = changes.reduceToLastChange()
            self?.replaceAndNotifyIfNeeded(finalItem, shouldDecodeAsPhase: shouldDecodeAsPhase)
        }

        let failure = { [weak self] (error: Error) in
            self?.replaceAndNotifyError(error)
            return
        }

        let localKey = localKeyFactory.createIdentifier(for: remoteKey)

        provider = providerFactory.createStorageProvider(for: localKey)

        provider?.addObserver(
            self,
            deliverOn: DispatchQueue.global(qos: .default),
            executing: updateClosure,
            failing: failure,
            options: StreamableProviderObserverOptions.substrateSource()
        )
    }

    private func prepareDecodingOperation() -> CompoundOperationWrapper<ElectionStatus?> {
        if let error = lastSeenResult.error {
            return CompoundOperationWrapper<ElectionStatus?>.createWithError(error)
        }

        guard let shouldDecodeAsPhase = lastSeenResult.shouldDecodeAsPhase else {
            return CompoundOperationWrapper.createWithResult(nil)
        }

        guard let data = lastSeenResult.data else {
            return CompoundOperationWrapper.createWithResult(ElectionStatus.close)
        }

        let decodingOperation = ClosureOperation<ElectionStatus?> {
            let scaleDecoder = try ScaleDecoder(data: data)

            if shouldDecodeAsPhase {
                let phase = try ElectionPhase(scaleDecoder: scaleDecoder)
                return ElectionStatus(phase: phase)
            } else {
                return try ElectionStatus(scaleDecoder: scaleDecoder)
            }
        }

        return CompoundOperationWrapper(targetOperation: decodingOperation)
    }
}

extension ElectionStatusSource {
    func fetchOperation(by modelId: String) -> CompoundOperationWrapper<Model?> {
        lock.lock()

        defer {
            lock.unlock()
        }

        guard modelId == itemIdentifier else {
            let value = ChainStorageDecodedItem<ElectionStatus>(identifier: modelId, item: nil)
            return CompoundOperationWrapper<Model?>.createWithResult(value)
        }

        let baseOperationWrapper = prepareDecodingOperation()
        let mappingOperation: BaseOperation<Model?> = ClosureOperation {
            if let item = try baseOperationWrapper.targetOperation.extractNoCancellableResultData() {
                return ChainStorageDecodedItem(identifier: modelId, item: item)
            } else {
                return ChainStorageDecodedItem(identifier: modelId, item: nil)
            }
        }

        let dependencies = baseOperationWrapper.allOperations
        dependencies.forEach { mappingOperation.addDependency($0) }

        if lastSeenResult.error != nil {
            // user needs data but we have some errors, try to repeat subscription
            resolveKeyAndSubscribe()
        }

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: dependencies
        )
    }

    func fetchOperation(page _: UInt) -> CompoundOperationWrapper<[Model]> {
        lock.lock()

        defer {
            lock.unlock()
        }

        let currentId = itemIdentifier

        let baseOperationWrapper = prepareDecodingOperation()
        let mappingOperation: BaseOperation<[Model]> = ClosureOperation {
            if let item = try baseOperationWrapper.targetOperation.extractNoCancellableResultData() {
                return [ChainStorageDecodedItem(identifier: currentId, item: item)]
            } else {
                return [ChainStorageDecodedItem(identifier: currentId, item: nil)]
            }
        }

        let dependencies = baseOperationWrapper.allOperations
        dependencies.forEach { mappingOperation.addDependency($0) }

        if lastSeenResult.error != nil {
            // user needs data but we have some errors, try to repeat subscription
            resolveKeyAndSubscribe()
        }

        return CompoundOperationWrapper(
            targetOperation: mappingOperation,
            dependencies: dependencies
        )
    }
}
