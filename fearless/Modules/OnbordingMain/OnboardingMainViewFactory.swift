import Foundation
import FearlessSecureStorage
import FearlessFoundation
import SSFCloudStorage
import SSFNetwork

final class OnboardingMainViewFactory: OnboardingMainViewFactoryProtocol {
    struct Dependencies {
        var keystoreImportServiceProvider: () -> KeystoreImportServiceProtocol?
        var logger: LoggerProtocol

        static var live: Dependencies {
            Dependencies(
                keystoreImportServiceProvider: URLHandlingDependencies.keystoreImportService,
                logger: Logger.shared
            )
        }
    }

    static func createViewForOnboarding() -> OnboardingMainViewProtocol? {
        createViewForOnboarding(dependencies: .live)
    }

    static func createViewForOnboarding(
        dependencies: Dependencies
    ) -> OnboardingMainViewProtocol? {
        let wireframe = OnboardingMainWireframe()
        return createView(for: wireframe, dependencies: dependencies)
    }

    static func createViewForAdding() -> OnboardingMainViewProtocol? {
        createViewForAdding(dependencies: .live)
    }

    static func createViewForAdding(
        dependencies: Dependencies
    ) -> OnboardingMainViewProtocol? {
        let wireframe = AddAccount.OnboardingMainWireframe()
        return createView(for: wireframe, dependencies: dependencies)
    }

    static func createViewForAccountSwitch() -> OnboardingMainViewProtocol? {
        createViewForAccountSwitch(dependencies: .live)
    }

    static func createViewForAccountSwitch(
        dependencies: Dependencies
    ) -> OnboardingMainViewProtocol? {
        let wireframe = SwitchAccount.OnboardingMainWireframe()
        return createView(for: wireframe, dependencies: dependencies)
    }

    private static func createView(
        for wireframe: OnboardingMainWireframeProtocol,
        dependencies: Dependencies
    ) -> OnboardingMainViewProtocol? {
        guard let keystoreImportService = dependencies.keystoreImportServiceProvider()
        else {
            dependencies.logger.error("Can't find required keystore import service")
            return nil
        }

        let applicationConfig: ApplicationConfigProtocol = ApplicationConfig.shared

        let locale: Locale = LocalizationManager.shared.selectedLocale

        let legalData = LegalData(
            termsUrl: applicationConfig.termsURL,
            privacyPolicyUrl: applicationConfig.privacyPolicyURL
        )

        let localizationManager = LocalizationManager.shared

        let view = OnboardingMainViewController(nib: R.nib.onbordingMain)
        view.termDecorator = CompoundAttributedStringDecorator.legal(for: locale)
        view.localizationManager = localizationManager

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
            keystoreImportService: keystoreImportService,
            cloudStorage: cloudStorage,
            featureToggleService: featureToggleProvider,
            operationQueue: OperationQueue()
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

        return view
    }
}
