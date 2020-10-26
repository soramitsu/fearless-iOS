import Foundation
import SoraKeystore
import CommonWallet
import FearlessUtils

final class MainTabBarInteractor {
	weak var presenter: MainTabBarInteractorOutputProtocol?

    let eventCenter: EventCenterProtocol
    let settings: SettingsManagerProtocol
    let webSocketService: WebSocketServiceProtocol
    let keystoreImportService: KeystoreImportServiceProtocol

    private var currentAccount: AccountItem?
    private var currentConnection: ConnectionItem?

    deinit {
        stopServices()
    }

    init(eventCenter: EventCenterProtocol,
         settings: SettingsManagerProtocol,
         webSocketService: WebSocketServiceProtocol,
         keystoreImportService: KeystoreImportServiceProtocol) {
        self.eventCenter = eventCenter
        self.settings = settings
        self.webSocketService = webSocketService
        self.keystoreImportService = keystoreImportService

        updateSelectedItems()

        startServices()
    }

    private func updateSelectedItems() {
        self.currentAccount = settings.selectedAccount
        self.currentConnection = settings.selectedConnection
    }

    private func startServices() {
        webSocketService.setup()
    }

    private func stopServices() {
        webSocketService.throttle()
    }

    private func updateWebSocketSettings() {
        let connectionItem = settings.selectedConnection
        let account = settings.selectedAccount

        let settings = WebSocketServiceSettings(url: connectionItem.url,
                                                addressType: connectionItem.type,
                                                address: account?.address)
        webSocketService.update(settings: settings)
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
            updateWebSocketSettings()
            updateSelectedItems()
            presenter?.didReloadSelectedAccount()
        }
    }

    func processSelectedConnectionChanged(event: SelectedConnectionChanged) {
        if currentConnection != settings.selectedConnection {
            updateWebSocketSettings()
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
