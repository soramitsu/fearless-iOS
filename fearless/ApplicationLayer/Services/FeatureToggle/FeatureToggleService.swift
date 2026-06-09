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

protocol FeatureToggleConfigSource {
    var featureToggleURL: URL? { get }
}

extension ApplicationConfig: FeatureToggleConfigSource {}

final class FeatureToggleProvider {
    struct PendingRequest {
        let resultClosure: (FeatureToggleConfig) -> Void
        let queue: DispatchQueue?
    }

    private let networkOperationFactory: NetworkOperationFactoryProtocol
    private let operationQueue: OperationQueue
    private let configSource: FeatureToggleConfigSource

    private(set) var snapshot: FeatureToggleConfig?
    private(set) var pendingRequests: [PendingRequest] = []

    init(
        networkOperationFactory: NetworkOperationFactoryProtocol,
        operationQueue: OperationQueue,
        configSource: FeatureToggleConfigSource = ApplicationConfig.shared
    ) {
        self.networkOperationFactory = networkOperationFactory
        self.operationQueue = operationQueue
        self.configSource = configSource

        do {
            try setup()
        } catch {
            snapshot = FeatureToggleConfig.defaultConfig
        }
    }

    private func setup() throws {
        guard let featureToggleURL = configSource.featureToggleURL else {
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
            guard let self = self else {
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
