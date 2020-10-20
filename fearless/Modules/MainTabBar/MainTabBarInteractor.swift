import Foundation
import SoraKeystore

final class MainTabBarInteractor {
	weak var presenter: MainTabBarInteractorOutputProtocol?

    let eventCenter: EventCenterProtocol
    let settings: SettingsManagerProtocol
    let webSocketService: WebSocketServiceProtocol

    private var currentAccount: AccountItem?
    private var currentConnection: ConnectionItem?

    deinit {
        stopServices()
    }

    init(eventCenter: EventCenterProtocol,
         settings: SettingsManagerProtocol,
         webSocketService: WebSocketServiceProtocol) {
        self.eventCenter = eventCenter
        self.settings = settings
        self.webSocketService = webSocketService

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

    private func updateWebSocketURL() {
        let newUrl = settings.selectedConnection.url

        webSocketService.update(url: newUrl)
    }
}

extension MainTabBarInteractor: MainTabBarInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)
    }
}

extension MainTabBarInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        if currentAccount != settings.selectedAccount {
            updateWebSocketURL()
            updateSelectedItems()
            presenter?.didReloadSelectedAccount()
        }
    }

    func processSelectedConnectionChanged(event: SelectedConnectionChanged) {
        if currentConnection != settings.selectedConnection {
            updateWebSocketURL()
            updateSelectedItems()
            presenter?.didReloadSelectedNetwork()
        }
    }
}
