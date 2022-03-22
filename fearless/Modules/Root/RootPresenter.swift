import UIKit
import SoraFoundation

final class RootPresenter {
    var view: RootViewProtocol?
    var window: UIWindow!
    var wireframe: RootWireframeProtocol!
    var interactor: RootInteractorInputProtocol!

    init(localizationManager: LocalizationManagerProtocol) {
        self.localizationManager = localizationManager
    }
}

extension RootPresenter: RootPresenterProtocol {
    func loadOnLaunch() {
        wireframe.showSplash(splashView: view, on: window)

        interactor.setup(runMigrations: true)
        interactor.checkAppVersion()
    }

    func reload() {
        interactor.setup(runMigrations: false)
        interactor.checkAppVersion()
    }
}

extension RootPresenter: RootInteractorOutputProtocol {
    func didDecideOnboarding() {
        wireframe.showOnboarding(on: window)
    }

    func didDecideLocalAuthentication() {
        wireframe.showLocalAuthentication(on: window)
    }

    func didDecidePincodeSetup() {
        wireframe.showPincodeSetup(on: window)
    }

    func didDecideBroken() {
        wireframe.showBroken(on: window)
    }

    func didDecideVersionUnsupported() {
        wireframe.presentWarningAlert(
            from: view,
            config: WarningAlertConfig.unsupportedAppVersionConfig(with: selectedLocale)
        ) { [weak self] in
            self?.wireframe.showAppstoreUpdatePage()
        }
    }

    func didFailCheckAppVersion() {
        wireframe.presentWarningAlert(
            from: view,
            config: WarningAlertConfig.connectionProblemAlertConfig(with: selectedLocale)
        ) { [weak self] in
            self?.interactor.checkAppVersion()
        }
    }
}

extension RootPresenter: Localizable {
    func applyLocalization() {}
}
