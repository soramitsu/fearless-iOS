import RobinHood
import SSFNetwork
import Foundation

enum OnboardingServiceError: Error {
    case urlBroken
    case empty
}

protocol OnboardingServiceProtocol {
    func fetchConfigs() async throws -> OnboardingConfigPlatform
}

actor OnboardingService {
    private let networkOperationFactory: NetworkOperationFactoryProtocol
    private let operationQueue: OperationQueue

    init(
        networkOperationFactory: NetworkOperationFactoryProtocol,
        operationQueue: OperationQueue
    ) {
        self.networkOperationFactory = networkOperationFactory
        self.operationQueue = operationQueue
    }
}

extension OnboardingService: OnboardingServiceProtocol {
    func fetchConfigs() async throws -> OnboardingConfigPlatform {
        guard let onboardingConfigUrl = ApplicationConfig.shared.onboardingConfig else {
            throw OnboardingServiceError.urlBroken
        }
        let request = RequestConfig(
            baseURL: onboardingConfigUrl,
            method: .get,
            endpoint: nil,
            headers: nil,
            body: nil,
            timeout: 5
        )
        let worker = NetworkWorkerImpl()
        return try await worker.performRequest(with: request)
    }
}
