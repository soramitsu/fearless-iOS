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
    private let eventCenter: EventCenterProtocol

    private let reachability: ReachabilityManager?
    private let networkStatusPresenter: NetworkAvailabilityLayerInteractorOutputProtocol
    private let walletConnectCoordinator: WalletConnectCoordinator

    private var crowdloanListView: UINavigationController?

    init(
        wireframe: MainTabBarWireframeProtocol,
        interactor: MainTabBarInteractorInputProtocol,
        appVersionObserver: AppVersionObserver,
        applicationHandler: ApplicationHandler,
        networkStatusPresenter: NetworkAvailabilityLayerInteractorOutputProtocol,
        reachability: ReachabilityManager?,
        walletConnectCoordinator: WalletConnectCoordinator,
        localizationManager: LocalizationManagerProtocol,
        eventCenter: EventCenterProtocol
    ) {
        self.wireframe = wireframe
        self.interactor = interactor
        self.appVersionObserver = appVersionObserver
        self.applicationHandler = applicationHandler
        self.networkStatusPresenter = networkStatusPresenter
        self.reachability = reachability
        self.walletConnectCoordinator = walletConnectCoordinator
        self.eventCenter = eventCenter

        self.localizationManager = localizationManager
        applicationHandler.delegate = self
    }
}

extension MainTabBarPresenter: MainTabBarPresenterProtocol {
    func presentPolkaswap() {
        guard let wallet = SelectedWalletSettings.shared.value else {
            return
        }
        wireframe.presentPolkaswap(on: view, wallet: wallet)
    }

    func didLoad(view: MainTabBarViewProtocol) {
        self.view = view

        interactor.setup(with: self)

        appVersionObserver.checkVersion(from: view, callback: nil)
        try? reachability?.add(listener: self)

        eventCenter.add(observer: self, dispatchIn: .main)
    }
}

extension MainTabBarPresenter: MainTabBarInteractorOutputProtocol {
    func didRequestImportAccount() {
        wireframe.presentAccountImport(on: view)
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

extension MainTabBarPresenter: StakingMainModuleOutput {
    func didSwitchStakingType(_ type: AssetSelectionStakingType) {
        wireframe.replaceStaking(on: view, type: type, moduleOutput: self)
    }
}

extension MainTabBarPresenter: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        guard event.account.ecosystem.isRegular else {
            return
        }

        wireframe.replaceStaking(on: view, type: .normal(chainAsset: nil), moduleOutput: self)
    }
}
