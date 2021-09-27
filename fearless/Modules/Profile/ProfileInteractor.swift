import Foundation
import SoraKeystore
import IrohaCrypto

enum ProfileInteractorError: Error {
    case noSelectedAccount
}

final class ProfileInteractor {
    weak var presenter: ProfileInteractorOutputProtocol?

    let selectedWalletSettings: SelectedWalletSettings
    let eventCenter: EventCenterProtocol

    init(
        selectedWalletSettings: SelectedWalletSettings,
        eventCenter: EventCenterProtocol
    ) {
        self.selectedWalletSettings = selectedWalletSettings
        self.eventCenter = eventCenter
    }

    private func provideUserSettings() {
        do {
            guard let wallet = selectedWalletSettings.value else {
                throw ProfileInteractorError.noSelectedAccount
            }

            // TODO: Apply total account value logic instead
            let genericAddress = try wallet.substrateAccountId.toAddress(
                using: ChainFormat.substrate(42)
            )

            let userSettings = UserSettings(
                userName: wallet.name,
                details: genericAddress
            )

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
    func processSelectedAccountChanged(event _: SelectedAccountChanged) {
        provideUserSettings()
    }

    func processSelectedUsernameChanged(event _: SelectedUsernameChanged) {
        provideUserSettings()
    }
}
