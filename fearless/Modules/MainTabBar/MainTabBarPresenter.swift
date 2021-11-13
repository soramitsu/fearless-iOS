import Foundation
import UIKit

final class MainTabBarPresenter {
    weak var view: MainTabBarViewProtocol?
    var interactor: MainTabBarInteractorInputProtocol!
    var wireframe: MainTabBarWireframeProtocol!

    private var crowdloanListView: UINavigationController?
}

extension MainTabBarPresenter: CrowdloanListModuleOutput {
    func didReceiveFailedMemos() {
        view?.presentFailedMemoView()
    }
}

extension MainTabBarPresenter: MainTabBarPresenterProtocol {
    func setup() {
        interactor.setup()
    }

    func viewDidAppear() {
        crowdloanListView = wireframe.showNewCrowdloan(on: view, moduleOutput: self) as? UINavigationController

        _ = crowdloanListView?.viewControllers.first?.view
    }
}

extension MainTabBarPresenter: MainTabBarInteractorOutputProtocol {
    func didReloadSelectedAccount() {
        wireframe.showNewWalletView(on: view)
        crowdloanListView = wireframe.showNewCrowdloan(on: view, moduleOutput: self) as? UINavigationController
    }

    func didReloadSelectedNetwork() {
        wireframe.showNewWalletView(on: view)
        crowdloanListView = wireframe.showNewCrowdloan(on: view, moduleOutput: self) as? UINavigationController
    }

    func didUpdateWalletInfo() {
        wireframe.reloadWalletContent()
    }

    func didRequestImportAccount() {
        wireframe.presentAccountImport(on: view)
    }

    func test() {}
}
