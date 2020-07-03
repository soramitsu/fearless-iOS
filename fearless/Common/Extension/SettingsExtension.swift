import Foundation
import SoraKeystore
import IrohaCrypto

enum SettingsKey: String {
    case selectedLocalization
    case accountId
    case biometryEnabled
}

extension SettingsManagerProtocol {
    var hasAccountId: Bool {
        accountId != nil
    }

    var accountId: Data? {
        get {
            data(for: SettingsKey.accountId.rawValue)
        }

        set {
            if let newValue = newValue {
                set(value: newValue, for: SettingsKey.accountId.rawValue)
            } else {
                removeValue(for: SettingsKey.accountId.rawValue)
            }
        }
    }

    var biometryEnabled: Bool? {
        get {
            bool(for: SettingsKey.biometryEnabled.rawValue)
        }

        set {
            if let existingValue = newValue {
                set(value: existingValue, for: SettingsKey.biometryEnabled.rawValue)
            } else {
                removeValue(for: SettingsKey.biometryEnabled.rawValue)
            }
        }
    }
}
