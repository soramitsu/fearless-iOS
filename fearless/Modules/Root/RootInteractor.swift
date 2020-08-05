import Foundation
import SoraKeystore
import IrohaCrypto
import RobinHood

final class RootInteractor {
    weak var presenter: RootInteractorOutputProtocol?

    var settings: SettingsManagerProtocol
    var keystore: KeystoreProtocol

    init(settings: SettingsManagerProtocol,
         keystore: KeystoreProtocol) {
        self.settings = settings
        self.keystore = keystore
    }
}

extension RootInteractor: RootInteractorInputProtocol {
    func decideModuleSynchroniously() {
        if !settings.hasSelectedAccount {
            presenter?.didDecideOnboarding()
            return
        }

        do {
            let pincodeExists = try keystore.checkKey(for: KeystoreTag.pincode.rawValue)

            if pincodeExists {
                presenter?.didDecideLocalAuthentication()
            } else {
                presenter?.didDecidePincodeSetup()
            }

        } catch {
            presenter?.didDecideBroken()
        }
    }

    func setup() {}
}
