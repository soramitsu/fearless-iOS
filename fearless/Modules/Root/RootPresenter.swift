import UIKit

final class RootPresenter {
    var view: RootViewProtocol?
    var window: UIWindow!
    var wireframe: RootWireframeProtocol!
    var interactor: RootInteractorInputProtocol!
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
        wireframe.showVersionUnsupported(from: view)
    }
}
