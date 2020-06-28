import Foundation
import SoraKeystore
import IrohaCrypto

enum SettingsKey: String {
    case selectedLocalization
    case accountId
}

extension SettingsManagerProtocol {
    var hasAccountId: Bool {
        string(for: SettingsKey.accountId.rawValue) != nil
    }
}
