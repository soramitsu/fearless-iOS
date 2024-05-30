import UIKit
import SoraKeystore

protocol OnboardingInteractorOutput: AnyObject {
    func didReceiveOnboardingConfig(_ config: OnboardingConfigWrapper)
}

final class OnboardingInteractor {
    // MARK: - Private properties

    private weak var output: OnboardingInteractorOutput?
    private let operationQueue: OperationQueue
    private let userDefaultsStorage: SettingsManagerProtocol
    private let config: OnboardingConfigWrapper

    init(
        operationQueue: OperationQueue,
        userDefaultsStorage: SettingsManagerProtocol,
        config: OnboardingConfigWrapper
    ) {
        self.operationQueue = operationQueue
        self.userDefaultsStorage = userDefaultsStorage
        self.config = config
    }

    func didClose() {
        if let appVersion: String = AppVersion.stringValue {
            userDefaultsStorage.set(
                value: appVersion,
                for: OnboardingKeys.lastShownOnboardingVersion.rawValue
            )
        }
    }
}

// MARK: - OnboardingInteractorInput

extension OnboardingInteractor: OnboardingInteractorInput {
    func setup(with output: OnboardingInteractorOutput) {
        self.output = output
        output.didReceiveOnboardingConfig(config)
    }
}
