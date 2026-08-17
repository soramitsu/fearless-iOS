import Foundation
import SSFNetwork
import RobinHood
import SSFUtils

enum FeatureToggleServiceError: Error {
    case urlBroken
}

protocol FeatureToggleProviderProtocol {
    func fetchConfigOperation() -> BaseOperation<FeatureToggleConfig>
}

final class FeatureToggleProvider {
    struct PendingRequest {
        let resultClosure: (FeatureToggleConfig) -> Void
        let queue: DispatchQueue?
    }

    private let networkOperationFactory: NetworkOperationFactoryProtocol
    private let operationQueue: OperationQueue
    private let stateLock = NSLock()

    private(set) var snapshot: FeatureToggleConfig?
    private(set) var pendingRequests: [PendingRequest] = []

    init(
        networkOperationFactory: NetworkOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.networkOperationFactory = networkOperationFactory
        self.operationQueue = operationQueue

        do {
            try setup()
        } catch {
            snapshot = FeatureToggleConfig.defaultConfig
            MultiChainFeaturePolicy.update(FeatureToggleConfig.defaultConfig)
        }
    }

    private func setup() throws {
        guard let featureToggleURL = ApplicationConfig.shared.featureToggleURL else {
            throw FeatureToggleServiceError.urlBroken
        }

        let fetchConfigOperation: BaseOperation<FeatureToggleConfig?> =
            networkOperationFactory.fetchData(from: featureToggleURL)

        fetchConfigOperation.completionBlock = { [weak self] in
            self?.handleCompletion(result: fetchConfigOperation.result)
        }

        operationQueue.addOperation(fetchConfigOperation)
    }

    private func fetchConfig(
        runCompletionIn queue: DispatchQueue?,
        executing closure: @escaping (FeatureToggleConfig) -> Void
    ) {
        let request = PendingRequest(resultClosure: closure, queue: queue)

        stateLock.lock()
        if let snapshot = snapshot {
            stateLock.unlock()
            deliver(snapshot: snapshot, to: request)
        } else {
            pendingRequests.append(request)
            stateLock.unlock()
        }
    }

    private func handleCompletion(result: Result<FeatureToggleConfig?, Error>?) {
        switch result {
        case let .success(snapshot):
            if let snapshot = snapshot {
                complete(with: snapshot)
            } else {
                handleDefault()
            }
        case .failure:
            handleDefault()
        case .none:
            handleDefault()
        }
    }

    private func handleDefault() {
        complete(with: FeatureToggleConfig.defaultConfig)
    }

    private func complete(with snapshot: FeatureToggleConfig) {
        MultiChainFeaturePolicy.update(snapshot)

        stateLock.lock()
        self.snapshot = snapshot
        let requests = pendingRequests
        pendingRequests = []
        stateLock.unlock()

        requests.forEach { deliver(snapshot: snapshot, to: $0) }
    }

    private func deliver(snapshot: FeatureToggleConfig, to request: PendingRequest) {
        dispatchInQueueWhenPossible(request.queue) {
            request.resultClosure(snapshot)
        }
    }
}

extension FeatureToggleProvider: FeatureToggleProviderProtocol {
    func fetchConfigOperation() -> BaseOperation<FeatureToggleConfig> {
        AwaitOperation { [weak self] in
            guard let self else {
                return FeatureToggleConfig.defaultConfig
            }

            return await withCheckedContinuation { continuation in
                self.fetchConfig(runCompletionIn: nil) { config in
                    continuation.resume(returning: config)
                }
            }
        }
    }
}
