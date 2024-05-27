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

    private func decideModuleSynchroniously() {
        let startView = startViewHelper.startView()
        switch startView {
        case .pin:
            wireframe.showLocalAuthentication(on: window)
        case .pinSetup:
            wireframe.showPincodeSetup(on: window)
        case .login:
            wireframe.showMain(on: window)
        case .broken:
            wireframe.showBroken(on: window)
        case .onboarding:
            wireframe.showOnboarding(on: window)
        }
    }
}

extension RootPresenter: RootPresenterProtocol {
    func loadOnLaunch() {
        wireframe.showSplash(splashView: view, on: window)

        interactor.setup(runMigrations: true)
        decideModuleSynchroniously()
    }

    func reload() {
        interactor.setup(runMigrations: false)
        decideModuleSynchroniously()
    }
}

extension RootPresenter: RootInteractorOutputProtocol {}

extension RootPresenter: Localizable {
    func applyLocalization() {}
}
