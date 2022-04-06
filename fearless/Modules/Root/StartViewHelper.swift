import Foundation
import SoraKeystore

enum StartView {
    case pin
    case pinSetup
    case login
    case broken
    case educationStories
}

protocol StartViewHelperProtocol {
    func startView() -> StartView
}

final class StartViewHelper: StartViewHelperProtocol {
    private let keystore: KeystoreProtocol
    private let selectedWallerSettings: SelectedWalletSettings
    private let userDefaultsStorage: SettingsManagerProtocol

    private lazy var isNeedShowStories: Bool = {
        userDefaultsStorage.bool(
            for: EducationStoriesKeys.isNeedShowNewsVersion2.rawValue
        ) ?? true
    }()

    init(
        keystore: KeystoreProtocol,
        selectedWallerSettings: SelectedWalletSettings,
        userDefaultsStorage: SettingsManagerProtocol
    ) {
        self.keystore = keystore
        self.selectedWallerSettings = selectedWallerSettings
        self.userDefaultsStorage = userDefaultsStorage
    }

    func startView() -> StartView {
        do {
            if isNeedShowStories, !selectedWallerSettings.hasValue {
                return StartView.educationStories
            }

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
