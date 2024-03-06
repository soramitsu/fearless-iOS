import RobinHood
import SSFNetwork
import Foundation

enum OnboardingServiceError: Error {
    case urlBroken
    case empty
}

protocol OnboardingServiceProtocol {
    func fetchConfig() async throws -> OnboardingConfigWrapper
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
    func fetchConfig() async throws -> OnboardingConfigWrapper {
        guard let onboardingConfigUrl = ApplicationConfig.shared.onboardingConfig else {
            throw OnboardingServiceError.urlBroken
        }
        let request = RequestConfig(
            baseURL: onboardingConfigUrl,
            method: .get,
            endpoint: nil,
            headers: nil,
            body: nil
        )
        let worker = NetworkWorker()
        return try await worker.performRequest(with: request)
    }
}
