import Foundation
import UIKit

final class MainTabBarPresenter {
    weak var view: MainTabBarViewProtocol?
    var interactor: MainTabBarInteractorInputProtocol!
    var wireframe: MainTabBarWireframeProtocol!

    private var crowdloanListView: UINavigationController?
}

extension MainTabBarPresenter: MainTabBarPresenterProtocol {
    func setup() {
        interactor.setup()
    }
}

extension MainTabBarPresenter: MainTabBarInteractorOutputProtocol {
    func didReloadSelectedAccount() {
        wireframe.showNewWalletView(on: view)
        crowdloanListView = wireframe.showNewCrowdloan(on: view) as? UINavigationController
    }

    func didReloadSelectedNetwork() {
        wireframe.showNewWalletView(on: view)
        crowdloanListView = wireframe.showNewCrowdloan(on: view) as? UINavigationController
    }

    func didUpdateWalletInfo() {}

    func didRequestImportAccount() {
        wireframe.presentAccountImport(on: view)
    }

    func handleLongInactivity() {
        wireframe.logout(from: view)
    }
}
