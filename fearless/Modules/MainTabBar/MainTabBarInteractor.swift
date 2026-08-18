import Foundation
import WalletConnectSign
import SoraKeystore

import SSFUtils
import SoraFoundation

final class MainTabBarInteractor {
    private weak var presenter: MainTabBarInteractorOutputProtocol?

    private let eventCenter: EventCenterProtocol
    private let keystoreImportService: KeystoreImportServiceProtocol
    private let serviceCoordinator: ServiceCoordinatorProtocol

    deinit {
        stopServices()
    }

    init(
        eventCenter: EventCenterProtocol,
        serviceCoordinator: ServiceCoordinatorProtocol,
        keystoreImportService: KeystoreImportServiceProtocol
    ) {
        self.eventCenter = eventCenter
        self.keystoreImportService = keystoreImportService
        self.serviceCoordinator = serviceCoordinator

        startServices()
    }

    private func startServices() {
        serviceCoordinator.setup()
    }

    private func stopServices() {
        serviceCoordinator.throttle()
    }

    private func requestPolkaswapRecovery() {
        DispatchQueue.main.async { [weak self] in
            self?.presenter?.didPrepareChains()
        }
    }
}

extension MainTabBarInteractor: MainTabBarInteractorInputProtocol {
    func setup(with output: MainTabBarInteractorOutputProtocol) {
        presenter = output

        eventCenter.add(observer: self, dispatchIn: nil)
        keystoreImportService.add(observer: self)

        if keystoreImportService.definition != nil {
            presenter?.didRequestImportAccount()
        }
        if let marketId = PolkamarktDeepLinkHandler.consumePending() {
            presenter?.didRequestPolkamarkt(marketId: marketId)
        }

        presenter?.didPrepareChains()
    }
}

extension MainTabBarInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        serviceCoordinator.updateOnAccountChange()
        DispatchQueue.main.async {
            self.presenter?.didChangeSelectedAccount(event.account)
        }
    }

    func processPolkamarktDeepLinkRequested(event: PolkamarktDeepLinkRequested) {
        _ = PolkamarktDeepLinkHandler.consumePending()
        DispatchQueue.main.async {
            self.presenter?.didRequestPolkamarkt(marketId: event.marketId)
        }
    }

    func processChainsSetupCompleted() {
        requestPolkaswapRecovery()
    }

    func processChainSyncDidComplete(event _: ChainSyncDidComplete) {
        requestPolkaswapRecovery()
    }

    func processChainsUpdated(event _: ChainsUpdatedEvent) {
        requestPolkaswapRecovery()
    }
}

extension MainTabBarInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from _: KeystoreDefinition?) {
        guard keystoreImportService.definition != nil else {
            return
        }

        presenter?.didRequestImportAccount()
    }
}
