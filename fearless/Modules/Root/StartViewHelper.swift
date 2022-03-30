import Foundation
import SoraKeystore

enum StartView {
    case pin
    case pinSetup
    case login
    case broken
}

protocol StartViewHelperProtocol {
    func startView() -> StartView
}

final class StartViewHelper: StartViewHelperProtocol {
    private let keystore: KeystoreProtocol
    private let selectedWallerSettings: SelectedWalletSettings

    init(
        keystore: KeystoreProtocol,
        selectedWallerSettings: SelectedWalletSettings
    ) {
        self.keystore = keystore
        self.selectedWallerSettings = selectedWallerSettings
    }

    func startView() -> StartView {
        do {
            if !selectedWallerSettings.hasValue {
                try keystore.deleteKeyIfExists(for: KeystoreTag.pincode.rawValue)

                return StartView.login
            }

            let pincodeExists = try keystore.checkKey(for: KeystoreTag.pincode.rawValue)

            if pincodeExists {
                return StartView.pin
            } else {
                return StartView.pinSetup
            }

        } catch {
            return StartView.broken
        }
    }
}
