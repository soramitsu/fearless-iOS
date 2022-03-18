import Foundation
import SoraKeystore
import CommonWallet
import FearlessUtils

final class MainTabBarInteractor {
    weak var presenter: MainTabBarInteractorOutputProtocol?

    let eventCenter: EventCenterProtocol
    let keystoreImportService: KeystoreImportServiceProtocol
    let serviceCoordinator: ServiceCoordinatorProtocol

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
}

extension MainTabBarInteractor: MainTabBarInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)
        keystoreImportService.add(observer: self)

        if keystoreImportService.definition != nil {
            presenter?.didRequestImportAccount()
        }
    }
}

extension MainTabBarInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        serviceCoordinator.updateOnAccountChange()
        presenter?.didReloadSelectedAccount()
    }

    func processBalanceChanged(event _: WalletBalanceChanged) {
        presenter?.didUpdateWalletInfo()
    }

    func processStakingChanged(event _: WalletStakingInfoChanged) {
        presenter?.didUpdateWalletInfo()
    }

    func processNewTransaction(event _: WalletNewTransactionInserted) {
        presenter?.didUpdateWalletInfo()
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
