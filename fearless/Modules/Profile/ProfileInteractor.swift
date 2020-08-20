import Foundation
import SoraKeystore
import IrohaCrypto

enum ProfileInteractorError: Error {
    case noSelectedAccount
}

final class ProfileInteractor {
	weak var presenter: ProfileInteractorOutputProtocol?

    let settingsManager: SettingsManagerProtocol
    let logger: LoggerProtocol

    init(settingsManager: SettingsManagerProtocol,
         logger: LoggerProtocol) {
        self.settingsManager = settingsManager
        self.logger = logger
    }
}

extension ProfileInteractor: ProfileInteractorInputProtocol {
    func setup() {
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
