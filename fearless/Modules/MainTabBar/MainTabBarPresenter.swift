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
    func didLoad(view: MainTabBarViewProtocol) {
        self.view = view

        interactor.setup(with: self)

        appVersionObserver.checkVersion(from: view, callback: nil)
        try? reachability?.add(listener: self)
    }
}

extension MainTabBarPresenter: MainTabBarInteractorOutputProtocol {
    func didReloadSelectedAccount() {
        crowdloanListView = wireframe.showNewCrowdloan(on: view) as? UINavigationController
    }

    func didRequestImportAccount() {
        wireframe.presentAccountImport(on: view)
    }

    func didReceive(proposal: Session.Proposal) {
        wireframe.showSession(
            proposal: proposal,
            view: view
        )
    }

    func didReceive(request: Request, session: Session?) {
        wireframe.showSign(
            request: request,
            session: session,
            view: view
        )
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
