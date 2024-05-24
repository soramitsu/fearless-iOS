import UIKit
import SoraFoundation

final class RootPresenter {
    var view: ControllerBackedProtocol?
    var window: UIWindow!
    var wireframe: RootWireframeProtocol!
    var interactor: RootInteractorInputProtocol!

    private let startViewHelper: StartViewHelperProtocol

    init(
        localizationManager: LocalizationManagerProtocol,
        startViewHelper: StartViewHelperProtocol
    ) {
        self.startViewHelper = startViewHelper
        self.localizationManager = localizationManager
    }

    private func decideModuleSynchroniously(with onboardingConfig: OnboardingConfigWrapper?) {
        let startView = startViewHelper.startView(onboardingConfig: onboardingConfig)
        switch startView {
        case .pin:
            wireframe.showLocalAuthentication(on: window)
        case .pinSetup:
            wireframe.showPincodeSetup(on: window)
        case .login:
            wireframe.showMain(on: window)
        case .broken:
            wireframe.showBroken(on: window)
        case let .onboarding(config):
            wireframe.showOnboarding(on: window, with: config)
        }
    }
}

extension RootPresenter: RootPresenterProtocol {
    func loadOnLaunch() {
        wireframe.showSplash(splashView: view, on: window)

        interactor.setup(runMigrations: true)
        Task {
            switch await interactor.fetchOnboardingConfig() {
            case let .success(onboardingConfig):
                DispatchQueue.main.async { [weak self] in
                    self?.decideModuleSynchroniously(with: onboardingConfig)
                }
            case let .failure(error):
                DispatchQueue.main.async { [weak self] in
                    Logger.shared.error(error.localizedDescription)
                    self?.decideModuleSynchroniously(with: nil)
                }
            }
        }
    }

    func reload() {
        interactor.setup(runMigrations: false)

        decideModuleSynchroniously(with: nil)
    }
}

extension RootPresenter: RootInteractorOutputProtocol {}

extension RootPresenter: Localizable {
    func applyLocalization() {}
}
