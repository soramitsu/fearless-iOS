import Foundation
import SoraKeystore
import CommonWallet
import FearlessUtils

final class MainTabBarInteractor {
    weak var presenter: MainTabBarInteractorOutputProtocol?

    let eventCenter: EventCenterProtocol
    let settings: SettingsManagerProtocol
    let keystoreImportService: KeystoreImportServiceProtocol
    let serviceCoordinator: ServiceCoordinatorProtocol

    private var currentAccount: AccountItem?
    private var currentConnection: ConnectionItem?

    deinit {
        stopServices()
    }

    init(eventCenter: EventCenterProtocol,
         settings: SettingsManagerProtocol,
         serviceCoordinator: ServiceCoordinatorProtocol,
         keystoreImportService: KeystoreImportServiceProtocol) {
        self.eventCenter = eventCenter
        self.settings = settings
        self.keystoreImportService = keystoreImportService
        self.serviceCoordinator = serviceCoordinator

        updateSelectedItems()

        startServices()
    }

    private func updateSelectedItems() {
        self.currentAccount = settings.selectedAccount
        self.currentConnection = settings.selectedConnection
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
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        if currentAccount != settings.selectedAccount {
            serviceCoordinator.updateOnAccountChange()
            updateSelectedItems()
            presenter?.didReloadSelectedAccount()
        }
    }

    func processSelectedConnectionChanged(event: SelectedConnectionChanged) {
        if currentConnection != settings.selectedConnection {
            serviceCoordinator.updateOnNetworkChange()
            updateSelectedItems()
            presenter?.didReloadSelectedNetwork()
        }
    }

    func processBalanceChanged(event: WalletBalanceChanged) {
        presenter?.didUpdateWalletInfo()
    }

    func processStakingChanged(event: WalletStakingInfoChanged) {
        presenter?.didUpdateWalletInfo()
    }

    func processNewTransaction(event: WalletNewTransactionInserted) {
        presenter?.didUpdateWalletInfo()
    }
}

extension MainTabBarInteractor: KeystoreImportObserver {
    func didUpdateDefinition(from oldDefinition: KeystoreDefinition?) {
        guard keystoreImportService.definition != nil else {
            return
        }

        presenter?.didRequestImportAccount()
    }
}
