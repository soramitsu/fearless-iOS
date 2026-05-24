import SSFNetwork
import Foundation

enum OnboardingServiceError: Error {
    case urlBroken
    case empty
}

protocol OnboardingServiceProtocol {
    func fetchConfigs() async throws -> OnboardingConfigPlatform
}

protocol OnboardingConfigSource {
    var onboardingConfig: URL? { get }
}

extension ApplicationConfig: OnboardingConfigSource {}

protocol OnboardingConfigFetching {
    func fetchConfig(from url: URL) async throws -> OnboardingConfigPlatform
}

final class OnboardingNetworkConfigFetcher: OnboardingConfigFetching {
    private let worker: NetworkWorkerDefault

    init(worker: NetworkWorkerDefault = NetworkWorkerDefault()) {
        self.worker = worker
    }

    func fetchConfig(from url: URL) async throws -> OnboardingConfigPlatform {
        let request = RequestConfig(
            baseURL: url,
            method: .get,
            endpoint: nil,
            headers: nil,
            body: nil
        )

        return try await worker.performRequest(with: request)
    }
}

actor OnboardingService {
    private let configSource: OnboardingConfigSource
    private let configFetcher: OnboardingConfigFetching

    init(
        configSource: OnboardingConfigSource = ApplicationConfig.shared,
        configFetcher: OnboardingConfigFetching = OnboardingNetworkConfigFetcher()
    ) {
        self.configSource = configSource
        self.configFetcher = configFetcher
    }
}

extension OnboardingService: OnboardingServiceProtocol {
    func fetchConfigs() async throws -> OnboardingConfigPlatform {
        guard let onboardingConfigUrl = configSource.onboardingConfig else {
            throw OnboardingServiceError.urlBroken
        }

        return try await configFetcher.fetchConfig(from: onboardingConfigUrl)
    }
}
