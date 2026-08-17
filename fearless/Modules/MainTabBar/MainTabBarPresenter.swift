import Foundation
import WalletConnectSign
import UIKit
import SoraFoundation
import SSFUtils

final class MainTabBarPresenter {
    private weak var view: MainTabBarViewProtocol?
    private let interactor: MainTabBarInteractorInputProtocol
    private let wireframe: MainTabBarWireframeProtocol
    private let appVersionObserver: AppVersionObserver
    private let applicationHandler: ApplicationHandler

    private let reachability: ReachabilityManager?
    private let networkStatusPresenter: NetworkAvailabilityLayerInteractorOutputProtocol
    private let walletConnectCoordinator: WalletConnectCoordinator

    init(
        wireframe: MainTabBarWireframeProtocol,
        interactor: MainTabBarInteractorInputProtocol,
        appVersionObserver: AppVersionObserver,
        applicationHandler: ApplicationHandler,
        networkStatusPresenter: NetworkAvailabilityLayerInteractorOutputProtocol,
        reachability: ReachabilityManager?,
        walletConnectCoordinator: WalletConnectCoordinator,
        localizationManager: LocalizationManagerProtocol
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.appVersionObserver = appVersionObserver
        self.applicationHandler = applicationHandler
        self.networkStatusPresenter = networkStatusPresenter
        self.reachability = reachability
        self.walletConnectCoordinator = walletConnectCoordinator
        self.localizationManager = localizationManager

        applicationHandler.delegate = self
    }
}

extension MainTabBarPresenter: MainTabBarPresenterProtocol {
    func didLoad(view: MainTabBarViewProtocol) {
        self.view = view

        interactor.setup(with: self)

        appVersionObserver.checkVersion(from: view, callback: nil)
        try? reachability?.add(listener: self)
    }
}

extension MainTabBarPresenter: MainTabBarInteractorOutputProtocol {
    func didChangeSelectedAccount(_ account: MetaAccountModel) {
        wireframe.reloadWalletDependentViews(on: view, wallet: account)
    }

    func didRequestImportAccount() {
        wireframe.presentAccountImport(on: view)
    }

    func didRequestPolkamarkt(marketId: String) {
        view?.openPolkamarkt(marketId: marketId)
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
    func didChangeReachability(by manager: ReachabilityManagerProtocol) {
        manager.isReachable
            ? networkStatusPresenter.didDecideReachableStatusPresentation()
            : networkStatusPresenter.didDecideUnreachableStatusPresentation()
    }
}
