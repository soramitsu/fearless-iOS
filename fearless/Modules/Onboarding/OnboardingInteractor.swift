import UIKit
import SoraKeystore

enum OnboardingKeys: String {
    case shouldShowOnboarding
}

protocol OnboardingInteractorOutput: AnyObject {
    func didReceiveOnboardingConfig(_ config: OnboardingConfigWrapper?) async
    func didReceiveOnboardingConfig(error: Error) async
}

final class OnboardingInteractor {
    // MARK: - Private properties

    private weak var output: OnboardingInteractorOutput?
    private let onboardingService: OnboardingServiceProtocol
    private let operationQueue: OperationQueue
    private let userDefaultsStorage: SettingsManagerProtocol
    private let onboardingConfigResolver = OnboardingConfigVersionResolver()

    init(
        onboardingService: OnboardingServiceProtocol,
        operationQueue: OperationQueue,
        userDefaultsStorage: SettingsManagerProtocol
    ) {
        self.onboardingService = onboardingService
        self.operationQueue = operationQueue
        self.userDefaultsStorage = userDefaultsStorage
    }

    private func loadConfig() async {
        do {
            let onboardingConfigPlatform = try await onboardingService.fetchConfigs()
            let onboardingWrappers = onboardingConfigPlatform.ios
            let currentConfig = onboardingConfigResolver.resolve(configWrappers: onboardingWrappers)
            await output?.didReceiveOnboardingConfig(currentConfig)
        } catch {
            await output?.didReceiveOnboardingConfig(error: error)
        }
    }

    func didClose() {
        userDefaultsStorage.set(
            value: false,
            for: OnboardingKeys.shouldShowOnboarding.rawValue
        )
    }
}

// MARK: - OnboardingInteractorInput

extension OnboardingInteractor: OnboardingInteractorInput {
    func setup(with output: OnboardingInteractorOutput) {
        self.output = output
        Task {
            await loadConfig()
        }
    }
}
