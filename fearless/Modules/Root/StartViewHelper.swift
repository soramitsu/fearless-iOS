import Foundation
import SoraKeystore

enum StartView {
    case pin
    case pinSetup
    case login
    case onboarding(OnboardingConfigWrapper)
}

enum StartViewError: LocalizedError {
    case selectedWalletUnavailable
    case selectedWalletMissing
    case unsupportedWalletRequiresCompatibility
    case startupRouteValidationUnavailable

    var errorDescription: String? {
        switch self {
        case .selectedWalletUnavailable:
            return "The selected wallet store is unavailable"
        case .selectedWalletMissing:
            return "The selected wallet store did not provide its validated wallet"
        case .unsupportedWalletRequiresCompatibility:
            return "The stored wallet requires a compatibility mapping"
        case .startupRouteValidationUnavailable:
            return "The validated startup route is unavailable"
        }
    }
}

protocol StartViewHelperProtocol {
    func startView(onboardingConfig: OnboardingConfigWrapper?) throws -> StartView
}

final class StartViewHelper: StartViewHelperProtocol {
    private let keystore: KeystoreProtocol
    private let selectedWalletSettingsProvider: () -> SelectedWalletSettings
    private lazy var selectedWalletSettings = selectedWalletSettingsProvider()
    private let userDefaultsStorage: SettingsManagerProtocol
    private let startupRouteValidationStore:
        RootStartupRouteValidationStore?
    private let updateSecurityNotice: UpdateSecurityNoticeTracking?

    init(
        keystore: KeystoreProtocol,
        selectedWalletSettingsProvider: @escaping () -> SelectedWalletSettings,
        userDefaultsStorage: SettingsManagerProtocol,
        startupRouteValidationStore: RootStartupRouteValidationStore? = nil,
        updateSecurityNotice: UpdateSecurityNoticeTracking? = nil
    ) {
        self.keystore = keystore
        self.selectedWalletSettingsProvider = selectedWalletSettingsProvider
        self.userDefaultsStorage = userDefaultsStorage
        self.startupRouteValidationStore = startupRouteValidationStore
        self.updateSecurityNotice = updateSecurityNotice
    }

    convenience init(
        keystore: KeystoreProtocol,
        selectedWalletSettings: SelectedWalletSettings,
        userDefaultsStorage: SettingsManagerProtocol,
        startupRouteValidationStore: RootStartupRouteValidationStore? = nil,
        updateSecurityNotice: UpdateSecurityNoticeTracking? = nil
    ) {
        self.init(
            keystore: keystore,
            selectedWalletSettingsProvider: { selectedWalletSettings },
            userDefaultsStorage: userDefaultsStorage,
            startupRouteValidationStore: startupRouteValidationStore,
            updateSecurityNotice: updateSecurityNotice
        )
    }

    func startView(onboardingConfig: OnboardingConfigWrapper?) throws -> StartView {
        if let startupRouteValidationStore {
            guard let validation = startupRouteValidationStore.take() else {
                throw StartViewError.startupRouteValidationUnavailable
            }

            if let hadStoredWallets = validation.hadStoredWallets {
                updateSecurityNotice?.recordStartup(hadStoredWallets: hadStoredWallets)
            }

            return startView(
                for: validation,
                onboardingConfig: onboardingConfig
            )
        }

        switch selectedWalletSettings.storeState {
        case .ready:
            guard selectedWalletSettings.hasValue else {
                throw StartViewError.selectedWalletMissing
            }
        case .empty:
            if let config = onboardingConfig {
                return .onboarding(config)
            }
            // An empty visible list may coexist with retained records and keys.
            // Keep existing authentication available for emergency recovery.
            return .login
        case .unsupportedOnly:
            let pincodeExists = try keystore.checkKey(for: KeystoreTag.pincode.rawValue)
            if pincodeExists {
                throw StartViewError.unsupportedWalletRequiresCompatibility
            }
            if let config = onboardingConfig {
                return .onboarding(config)
            }
            return .login
        case .unavailable:
            guard try !keystore.checkKey(for: KeystoreTag.pincode.rawValue) else {
                throw StartViewError.selectedWalletUnavailable
            }
            return .login
        case .unresolved:
            throw StartViewError.selectedWalletUnavailable
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
    }

    private func startView(
        for validation: RootStartupRouteValidation,
        onboardingConfig: OnboardingConfigWrapper?
    ) -> StartView {
        if let config = onboardingConfig {
            return .onboarding(config)
        }

        switch validation {
        case let .ready(pincodeAvailable):
            return pincodeAvailable ? .pin : .pinSetup
        case .empty, .unsupportedOnlyWithoutPincode, .unavailableWithoutPincode:
            return .login
        }
    }
}

private extension RootStartupRouteValidation {
    /// Whether wallets were stored before this startup; nil while the wallet store cannot be read.
    var hadStoredWallets: Bool? {
        switch self {
        case .ready, .unsupportedOnlyWithoutPincode:
            return true
        case .empty:
            return false
        case .unavailableWithoutPincode:
            return nil
        }
    }
}
