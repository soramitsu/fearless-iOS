import Foundation
import SoraKeystore

enum StartView {
    case pin
    case pinSetup
    case login
    case broken
    case unsupportedWallet
    case onboarding(OnboardingConfigWrapper)
}

protocol StartViewHelperProtocol {
    func startView(onboardingConfig: OnboardingConfigWrapper?) -> StartView
}

final class StartViewHelper: StartViewHelperProtocol {
    private let keystore: KeystoreProtocol
    private let selectedWalletSettingsProvider: () -> SelectedWalletSettings
    private lazy var selectedWalletSettings = selectedWalletSettingsProvider()
    private let userDefaultsStorage: SettingsManagerProtocol

    init(
        keystore: KeystoreProtocol,
        selectedWalletSettingsProvider: @escaping () -> SelectedWalletSettings,
        userDefaultsStorage: SettingsManagerProtocol
    ) {
        self.keystore = keystore
        self.selectedWalletSettingsProvider = selectedWalletSettingsProvider
        self.userDefaultsStorage = userDefaultsStorage
    }

    convenience init(
        keystore: KeystoreProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        userDefaultsStorage: SettingsManagerProtocol
    ) {
        self.init(
            keystore: keystore,
            selectedWalletSettingsProvider: { selectedWalletSettings },
            userDefaultsStorage: userDefaultsStorage
        )
    }

    func startView(onboardingConfig: OnboardingConfigWrapper?) -> StartView {
        do {
            switch selectedWalletSettings.storeState {
            case .ready:
                guard selectedWalletSettings.hasValue else {
                    return .broken
                }
            case .empty:
                if let config = onboardingConfig {
                    return .onboarding(config)
                }
                try keystore.deleteKeyIfExists(for: KeystoreTag.pincode.rawValue)
                return .login
            case .unsupportedOnly:
                let pincodeExists = try keystore.checkKey(for: KeystoreTag.pincode.rawValue)
                if pincodeExists {
                    return .unsupportedWallet
                }
                if let config = onboardingConfig {
                    return .onboarding(config)
                }
                return .login
            case .unresolved, .unavailable:
                return .broken
            }

            if let config = onboardingConfig {
                return .onboarding(config)
            }
            let pincodeExists = try keystore.checkKey(for: KeystoreTag.pincode.rawValue)

            if pincodeExists {
                return .pin
            } else {
                return .pinSetup
            }

        } catch {
            return .broken
        }
    }
}
