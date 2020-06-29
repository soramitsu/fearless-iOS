import Foundation
import SoraKeystore
import IrohaCrypto

enum SettingsKey: String {
    case selectedLocalization
    case accountId
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
}
