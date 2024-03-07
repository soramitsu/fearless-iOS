import Foundation
import SoraKeystore

enum StartView {
    case pin
    case pinSetup
    case login
    case broken
    case onboarding
}

protocol StartViewHelperProtocol {
    func startView() -> StartView
}

final class StartViewHelper: StartViewHelperProtocol {
    private let keystore: KeystoreProtocol
    private let selectedWalletSettings: SelectedWalletSettings
    private let userDefaultsStorage: SettingsManagerProtocol

    private lazy var isNeedShowOnboarding: Bool = {
        userDefaultsStorage.bool(
            for: OnboardingKeys.shouldShowOnboarding.rawValue
        ) ?? true
    }()

    init(
        keystore: KeystoreProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        userDefaultsStorage: SettingsManagerProtocol
    ) {
        self.keystore = keystore
        self.selectedWalletSettings = selectedWalletSettings
        self.userDefaultsStorage = userDefaultsStorage
    }

    func startView() -> StartView {
        do {
            if isNeedShowOnboarding, !selectedWalletSettings.hasValue {
                return StartView.onboarding
            }

            if !selectedWalletSettings.hasValue {
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
