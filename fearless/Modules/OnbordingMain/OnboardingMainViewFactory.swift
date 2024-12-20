import Foundation
import SoraKeystore
import SoraFoundation
import SSFCloudStorage
import SSFNetwork

final class OnboardingMainViewFactory: OnboardingMainViewFactoryProtocol {
    static func createViewForOnboarding() -> OnboardingMainViewProtocol? {
        let wireframe = OnboardingMainWireframe()
        return createView(for: wireframe, ecosystem: nil)
    }

    static func createViewForAdding(ecosystem: AccountCreateEcosystem?) -> OnboardingMainViewProtocol? {
        let wireframe = AddAccount.OnboardingMainWireframe()
        return createView(for: wireframe, ecosystem: ecosystem)
    }

    static func createViewForAccountSwitch() -> OnboardingMainViewProtocol? {
        let wireframe = SwitchAccount.OnboardingMainWireframe()
        return createView(for: wireframe, ecosystem: nil)
    }

    private static func createView(
        for wireframe: OnboardingMainWireframeProtocol,
        ecosystem: AccountCreateEcosystem?
    ) -> OnboardingMainViewProtocol? {
        guard let kestoreImportService: KeystoreImportServiceProtocol =
            URLHandlingService.shared.findService()
        else {
            Logger.shared.error("Can't find required keystore import service")
            return nil
        }

        let applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared

        let locale: Locale = LocalizationManager.shared.selectedLocale

        let legalData = LegalData(
            termsUrl: applicationConfig.termsURL,
            privacyPolicyUrl: applicationConfig.privacyPolicyURL
        )

        let localizationManager = LocalizationManager.shared

        let view = OnboardingMainViewController(ecosystem: ecosystem)

        let appVersionObserver = AppVersionObserver(
            operationManager: OperationManagerFacade.sharedManager,
            currentAppVersion: AppVersion.stringValue,
            wireframe: wireframe,
            locale: localizationManager.selectedLocale
        )

        let cloudStorage = CloudStorageService(
            uiDelegate: view
        )

        let featureToggleProvider = FeatureToggleProvider(
            networkOperationFactory: NetworkOperationFactory(jsonDecoder: GithubJSONDecoder()),
            operationQueue: OperationQueue()
        )

        let interactor = OnboardingMainInteractor(
            keystoreImportService: kestoreImportService,
            cloudStorage: cloudStorage,
            featureToggleService: featureToggleProvider,
            operationQueue: OperationQueue(),
            accountOperationFactory: MetaAccountOperationFactory(keystore: Keychain()),
            settings: SelectedWalletSettings.shared,
            eventCenter: ServiceAssembly.shared.eventCenter
        )

        let presenter = OnboardingMainPresenter(
            legalData: legalData,
            locale: locale,
            appVersionObserver: appVersionObserver,
            wireframe: wireframe,
            interactor: interactor
        )

        view.presenter = presenter
        presenter.view = view

        interactor.presenter = presenter
        view.localizationManager = localizationManager

        return view
    }
}
