import UIKit
import SoraFoundation
import SSFNetwork
import SoraKeystore

final class OnboardingAssembly {
    static func configureModule() -> OnboardingModuleCreationResult? {
        let localizationManager = LocalizationManager.shared

        let service = OnboardingService(
            networkOperationFactory: NetworkOperationFactory(jsonDecoder: GithubJSONDecoder()),
            operationQueue: OperationQueue()
        )
        let userDefaultsStorage = SettingsManager.shared
        let keychain = Keychain()
        let startViewHelper = StartViewHelper(
            keystore: keychain,
            selectedWalletSettings: SelectedWalletSettings.shared,
            userDefaultsStorage: SettingsManager.shared
        )

        let interactor = OnboardingInteractor(
            onboardingService: service,
            operationQueue: OperationQueue(),
            userDefaultsStorage: userDefaultsStorage
        )
        let router = OnboardingRouter()

        let pagesFactory = OnboardingPagesFactory()

        let presenter = OnboardingPresenter(
            interactor: interactor,
            router: router,
            pagesFactory: pagesFactory,
            startViewHelper: startViewHelper,
            localizationManager: localizationManager
        )

        let view = OnboardingViewController(
            output: presenter,
            localizationManager: localizationManager
        )

        return (view, presenter)
    }
}
