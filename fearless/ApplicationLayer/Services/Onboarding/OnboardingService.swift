import RobinHood
import SSFNetwork
import Foundation

enum OnboardingServiceError: Error {
    case urlBroken
    case empty
}

protocol OnboardingServiceProtocol {
    func fetchConfigOperation() -> BaseOperation<OnboardingConfigWrapper>
}

final class OnboardingService {
    private let networkOperationFactory: NetworkOperationFactoryProtocol
    private let operationQueue: OperationQueue

    init(
        networkOperationFactory: NetworkOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.networkOperationFactory = networkOperationFactory
        self.operationQueue = operationQueue
    }

    private func fetchConfig(
        runCompletionIn _: DispatchQueue?,
        executing closure: @escaping (OnboardingConfigWrapper) -> Void
    ) {
        guard let onboardingConfigUrl = ApplicationConfig.shared.onboardingConfig else {
            Logger.shared.customError(OnboardingServiceError.urlBroken)
            return
        }
        let fetchConfigOperation: BaseOperation<OnboardingConfigWrapper> = networkOperationFactory.fetchData(from: onboardingConfigUrl)

        fetchConfigOperation.completionBlock = { [weak self] in
            self?.handle(result: fetchConfigOperation.result, executing: closure)
        }

        operationQueue.addOperation(fetchConfigOperation)
    }

    private func handle(
        result: Result<OnboardingConfigWrapper, Error>?,
        executing closure: @escaping (OnboardingConfigWrapper) -> Void
    ) {
        switch result {
        case let .success(config):
            closure(config)
        case let .failure(error):
            Logger.shared.customError(error)
        case .none:
            Logger.shared.customError(OnboardingServiceError.empty)
        }
    }
}

extension OnboardingService: OnboardingServiceProtocol {
    func fetchConfigOperation() -> BaseOperation<OnboardingConfigWrapper> {
        AwaitOperation { [weak self] in
            try await withCheckedThrowingContinuation { continuation in
                self?.fetchConfig(runCompletionIn: nil) { factory in
                    continuation.resume(with: .success(factory))
                }
            }
        }
    }
}
