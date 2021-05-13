import Foundation
import SoraKeystore

final class InconsistentStateMigrator: Migrating {
    private(set) var settings: SettingsManagerProtocol
    private(set) var keychain: KeystoreProtocol

    init(
        settings: SettingsManagerProtocol,
        keychain: KeystoreProtocol
    ) {
        self.settings = settings
        self.keychain = keychain
    }

    func migrate() throws {
        guard let selectedAccount = settings.selectedAccount else {
            return
        }

        let hasSecretKey = try keychain.checkSecretKeyForAddress(selectedAccount.address)

        if !hasSecretKey {
            settings.removeAll()
        }
    }
}
