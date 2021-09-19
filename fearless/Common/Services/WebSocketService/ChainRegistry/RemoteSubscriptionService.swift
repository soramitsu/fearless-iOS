import Foundation
import RobinHood
import FearlessUtils

typealias RemoteSubscriptionClosure = (Result<Void, Error>) -> Void

protocol RemoteSubscriptionServiceProtocol {
    func subscribeToBlockNumber(
        for chainId: ChainModel.Id,
        runningCompletionIn queue: DispatchQueue?,
        completion closure: RemoteSubscriptionClosure?
    )

    func unsubscribeFromBlockNumber(
        for chainId: ChainModel.Id,
        runningCompletionIn queue: DispatchQueue?,
        completion closure: RemoteSubscriptionClosure?
    )
}

extension RemoteSubscriptionServiceProtocol {
    func subscribeToBlockNumber(for chainId: ChainModel.Id) {
        subscribeToBlockNumber(for: chainId, runningCompletionIn: nil, completion: nil)
    }

    func unsubscribeFromBlockNumber(for chainId: ChainModel.Id) {
        unsubscribeFromBlockNumber(for: chainId, runningCompletionIn: nil, completion: nil)
    }
}

enum RemoteSubscriptionServiceError: Error {
    case connectionUnavailable
    case runtimeMetadaUnavailable
}

class RemoteSubscriptionService {
    let chainRegistry: ChainRegistryProtocol
    let repository: AnyDataProviderRepository<ChainStorageItem>
    let operationManager: OperationManagerProtocol
    let logger: LoggerProtocol

    private var containers: [String: WeakWrapper]

    init(
        chainRegistry: ChainRegistryProtocol,
        repository: AnyDataProviderRepository<ChainStorageItem>,
        operationManager: OperationManagerProtocol,
        logger: LoggerProtocol
    ) {
        self.chainRegistry = chainRegistry
        self.repository = repository
        self.operationManager = operationManager
        self.logger = logger
    }
}

extension RemoteSubscriptionService: RemoteSubscriptionServiceProtocol {
    func subscribeToBlockNumber(
        for chainId: ChainModel.Id,
        runningCompletionIn queue: DispatchQueue?,
        completion closure: RemoteSubscriptionClosure?
    ) {
        guard let runtimeProvider = chainRegistry.getRuntimeProvider(for: chainId) else {
            if let closure = closure {
                dispatchInQueueWhenPossible(queue, block: {
                    closure(.failure(RemoteSubscriptionServiceError.runtimeMetadaUnavailable))
                })
            }
            return
        }

        let coderFactoryOperation = runtimeProvider.fetchCoderFactoryOperation()

        let keyEncodingOperation = UnkeyedEncodingOperation(
            path: StorageCodingPath.blockNumber,
            storageKeyFactory: storageKeyFactory
        )

        keyEncodingOperation.configurationBlock = {
            do {
                keyEncodingOperation.codingFactory = try coderFactoryOperation.extractNoCancellableResultData()
            } catch {
                keyEncodingOperation.result = .failure(error)
            }
        }

        keyEncodingOperation.addDependency(coderFactoryOperation)

        let subscriptionOperation = ClosureOperation {
            let remoteKey = try keyEncodingOperation.extractNoCancellableResultData()
            let localKey = try self.localStorageKeyFactory.createKey(from: remoteKey, chainId: chainId)

            guard let connection = self.chainRegistry.getConnection(for: chainId) else {
                throw RemoteSubscriptionServiceError.connectionUnavailable
            }

            let subscription = EmptyHandlingStorageSubscription(
                remoteStorageKey: remoteKey,
                localStorageKey: localKey,
                storage: self.repository,
                operationManager: self.operationManager,
                logger: self.logger
            )

            let container = StorageSubscriptionContainer(
                engine: connection,
                children: [subscription],
                logger: self.logger
            )
        }
    }

    func unsubscribeFromBlockNumber(
        for _: ChainModel.Id,
        runningCompletionIn _: DispatchQueue?,
        completion _: RemoteSubscriptionClosure?
    ) {}
}
