import Foundation
import UIKit
import SoraFoundation

final class MainTabBarPresenter {
    weak var view: MainTabBarViewProtocol?
    var interactor: MainTabBarInteractorInputProtocol
    var wireframe: MainTabBarWireframeProtocol
    let appVersionObserver: AppVersionObserver
    let applicationHandler: ApplicationHandler

    private var crowdloanListView: UINavigationController?

    init(
        wireframe: MainTabBarWireframeProtocol,
        interactor: MainTabBarInteractorInputProtocol,
        appVersionObserver: AppVersionObserver,
        applicationHandler: ApplicationHandler,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.appVersionObserver = appVersionObserver
        self.applicationHandler = applicationHandler
        self.localizationManager = localizationManager
    }
}

extension MainTabBarPresenter: MainTabBarPresenterProtocol {
    func setup() {
        interactor.setup()

        appVersionObserver.checkVersion(from: view, callback: nil)
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

extension MainTabBarPresenter: Localizable {
    func applyLocalization() {}
}

extension MainTabBarPresenter: ApplicationHandlerDelegate {
    func didReceiveWillEnterForeground(notification _: Notification) {
        appVersionObserver.checkVersion(from: view, callback: nil)
    }
}
