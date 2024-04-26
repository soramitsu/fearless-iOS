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
        }
    }

    private func setup() throws {
        guard let featureToggleURL = ApplicationConfig.shared.featureToggleURL else {
            throw FeatureToggleServiceError.urlBroken
        }

        let fetchConfigOperation: BaseOperation<FeatureToggleConfig?> = networkOperationFactory.fetchData(from: featureToggleURL)

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

        if let snapshot = snapshot {
            deliver(snapshot: snapshot, to: request)
        } else {
            pendingRequests.append(request)
        }
    }

    private func handleCompletion(result: Result<FeatureToggleConfig?, Error>?) {
        switch result {
        case let .success(snapshot):
            if let snapshot = snapshot {
                self.snapshot = snapshot
                resolveRequests()
            }
        case .failure:
            handleDefault()
        case .none:
            handleDefault()
        }
    }

    private func handleDefault() {
        snapshot = FeatureToggleConfig.defaultConfig
        resolveRequests()
    }

    private func resolveRequests() {
        guard !pendingRequests.isEmpty, let snapshot = snapshot else {
            return
        }

        let requests = pendingRequests
        pendingRequests = []

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
            try await withCheckedThrowingContinuation { continuation in
                var nillableContinuation: CheckedContinuation<FeatureToggleConfig, Error>? = continuation

                self?.fetchConfig(runCompletionIn: nil) { factory in
                    guard let unwrapedContinuation = nillableContinuation else {
                        return
                    }
                    unwrapedContinuation.resume(with: .success(factory))
                    nillableContinuation = nil
                }
            }
        }
    }
}
