import UIKit
import SoraKeystore

enum OnboardingKeys: String {
    case shouldShowOnboarding
}

protocol OnboardingInteractorOutput: AnyObject {
    func didReceiveOnboardingConfig(result: Result<OnboardingConfigWrapper, Error>?)
}

final class OnboardingInteractor {
    // MARK: - Private properties

    private weak var output: OnboardingInteractorOutput?
    private let onboardingService: OnboardingServiceProtocol
    private let operationQueue: OperationQueue
    private let userDefaultsStorage: SettingsManagerProtocol

    init(
        onboardingService: OnboardingServiceProtocol,
        operationQueue: OperationQueue,
        userDefaultsStorage: SettingsManagerProtocol
    ) {
        self.onboardingService = onboardingService
        self.operationQueue = operationQueue
        self.userDefaultsStorage = userDefaultsStorage
    }

    private func loadConfig() {
        let fetchOperation = onboardingService.fetchConfigOperation()
        fetchOperation.completionBlock = { [weak self] in
            DispatchQueue.main.async {
                self?.output?.didReceiveOnboardingConfig(result: fetchOperation.result)
            }
        }
        operationQueue.addOperation(fetchOperation)
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
        loadConfig()
    }
}
