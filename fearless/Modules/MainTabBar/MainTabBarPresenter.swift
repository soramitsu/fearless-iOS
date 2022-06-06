import Foundation
import UIKit
import SoraFoundation
import FearlessUtils

final class MainTabBarPresenter {
    weak var view: MainTabBarViewProtocol?

    private let interactor: MainTabBarInteractorInputProtocol
    private let wireframe: MainTabBarWireframeProtocol
    private let appVersionObserver: AppVersionObserver
    private let applicationHandler: ApplicationHandler

    private var chainsSyncFailed = false
    private let reachability: ReachabilityManager?
    private let networkStatusPresenter: NetworkAvailabilityLayerInteractorOutputProtocol

    private var crowdloanListView: UINavigationController?

    init(
        wireframe: MainTabBarWireframeProtocol,
        interactor: MainTabBarInteractorInputProtocol,
        appVersionObserver: AppVersionObserver,
        applicationHandler: ApplicationHandler,
        networkStatusPresenter: NetworkAvailabilityLayerInteractorOutputProtocol,
        reachability: ReachabilityManager?,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.appVersionObserver = appVersionObserver
        self.applicationHandler = applicationHandler
        self.networkStatusPresenter = networkStatusPresenter
        self.reachability = reachability
        self.localizationManager = localizationManager

        applicationHandler.delegate = self
    }
}

extension MainTabBarPresenter: MainTabBarPresenterProtocol {
    func setup() {
        assertNotNil(view) // should be called from view on appear
        // Update reachability if decided before view set
        if let reachability = reachability {
            didChangeReachability(by: reachability)
        }

        interactor.setup()

        appVersionObserver.checkVersion(from: view, callback: nil)
        try? reachability?.add(listener: self)
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

    func chainSyncFinished(success: Bool) {
        chainsSyncFailed = !success
        if let reachability = reachability {
            didChangeReachability(by: reachability)
        }
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

extension MainTabBarPresenter: ReachabilityListenerDelegate {
    func didChangeReachability(by _: ReachabilityManagerProtocol) {
        assertNotNil(reachability)

        let isReachable = (reachability?.isReachable).orTrue() && !chainsSyncFailed
        if isReachable {
            networkStatusPresenter.didDecideReachableStatusPresentation()
        } else {
            networkStatusPresenter.didDecideUnreachableStatusPresentation()
        }
    }
}
