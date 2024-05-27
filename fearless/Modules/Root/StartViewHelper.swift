import Foundation
import SoraKeystore

enum StartView {
    case pin
    case pinSetup
    case login
    case broken
    case onboarding(OnboardingConfigWrapper)
}

protocol StartViewHelperProtocol {
    func startView(onboardingConfig: OnboardingConfigWrapper?) -> StartView
}

final class StartViewHelper: StartViewHelperProtocol {
    private let keystore: KeystoreProtocol
    private let selectedWalletSettings: SelectedWalletSettings
    private let userDefaultsStorage: SettingsManagerProtocol

    init(
        keystore: KeystoreProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        userDefaultsStorage: SettingsManagerProtocol
    ) {
        self.keystore = keystore
        self.selectedWalletSettings = selectedWalletSettings
        self.userDefaultsStorage = userDefaultsStorage
    }

    func startView(onboardingConfig: OnboardingConfigWrapper?) -> StartView {
        do {
            if let config = onboardingConfig {
                return StartView.onboarding(config)
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
