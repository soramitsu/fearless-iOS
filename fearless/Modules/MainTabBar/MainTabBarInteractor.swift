import Foundation
import SoraKeystore

final class MainTabBarInteractor {
	weak var presenter: MainTabBarInteractorOutputProtocol?

    let eventCenter: EventCenterProtocol
    let settings: SettingsManagerProtocol

    private var currentAccount: AccountItem?
    private var currentConnection: ConnectionItem?

    init(eventCenter: EventCenterProtocol, settings: SettingsManagerProtocol) {
        self.eventCenter = eventCenter
        self.settings = settings

        updateSelectedItems()
    }

    private func updateSelectedItems() {
        self.currentAccount = settings.selectedAccount
        self.currentConnection = settings.selectedConnection
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
            updateSelectedItems()
            presenter?.didReloadSelectedAccount()
        }
    }

    func processSelectedConnectionChanged(event: SelectedConnectionChanged) {
        if currentConnection != settings.selectedConnection {
            updateSelectedItems()
            presenter?.didReloadSelectedNetwork()
        }
    }
}
