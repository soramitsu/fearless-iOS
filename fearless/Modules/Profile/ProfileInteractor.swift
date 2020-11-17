import Foundation
import SoraKeystore
import IrohaCrypto

enum ProfileInteractorError: Error {
    case noSelectedAccount
}

final class ProfileInteractor {
	weak var presenter: ProfileInteractorOutputProtocol?

    let settingsManager: SettingsManagerProtocol
    let eventCenter: EventCenterProtocol
    let logger: LoggerProtocol

    init(settingsManager: SettingsManagerProtocol,
         eventCenter: EventCenterProtocol,
         logger: LoggerProtocol) {
        self.settingsManager = settingsManager
        self.eventCenter = eventCenter
        self.logger = logger
    }

    private func provideUserSettings() {
        do {
            guard let account = settingsManager.selectedAccount else {
                throw ProfileInteractorError.noSelectedAccount
            }

            let connection = settingsManager.selectedConnection

            let userSettings = UserSettings(account: account,
                                            connection: connection)

            presenter?.didReceive(userSettings: userSettings)
        } catch {
            presenter?.didReceiveUserDataProvider(error: error)
        }
    }
}

extension ProfileInteractor: ProfileInteractorInputProtocol {
    func setup() {
        eventCenter.add(observer: self, dispatchIn: .main)
        provideUserSettings()
    }
}

extension ProfileInteractor: EventVisitorProtocol {
    func processSelectedAccountChanged(event: SelectedAccountChanged) {
        provideUserSettings()
    }

    func processSelectedUsernameChanged(event: SelectedUsernameChanged) {
        provideUserSettings()
    }
}
