import UIKit

final class RootPresenter {
    var view: UIWindow!
    var wireframe: RootWireframeProtocol!
    var interactor: RootInteractorInputProtocol!
}

extension RootPresenter: RootPresenterProtocol {
    func loadOnLaunch() {
        interactor.setup()
        interactor.decideModuleSynchroniously()
    }
}

extension RootPresenter: RootInteractorOutputProtocol {
    func didDecideOnboarding() {
        wireframe.showOnboarding(on: view)
    }

    func didDecideLocalAuthentication() {
        wireframe.showLocalAuthentication(on: view)
    }

    func didDecidePincodeSetup() {
        wireframe.showPincodeSetup(on: view)
    }

    func didDecideBroken() {
        wireframe.showBroken(on: view)
    }
}
